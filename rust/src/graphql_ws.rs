use crate::error::WinCCError;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};

#[derive(Clone)]
pub struct SubscriptionCallbacks {
    pub on_data: Arc<dyn Fn(Value) + Send + Sync>,
    pub on_error: Option<Arc<dyn Fn(String) + Send + Sync>>,
    pub on_complete: Option<Arc<dyn Fn() + Send + Sync>>,
}

impl SubscriptionCallbacks {
    pub fn new(on_data: impl Fn(Value) + Send + Sync + 'static) -> Self {
        Self {
            on_data: Arc::new(on_data),
            on_error: None,
            on_complete: None,
        }
    }

    pub fn with_error(mut self, on_error: impl Fn(String) + Send + Sync + 'static) -> Self {
        self.on_error = Some(Arc::new(on_error));
        self
    }

    pub fn with_complete(mut self, on_complete: impl Fn() + Send + Sync + 'static) -> Self {
        self.on_complete = Some(Arc::new(on_complete));
        self
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum WSMessage {
    ConnectionInit {
        payload: HashMap<String, String>,
    },
    ConnectionAck,
    ConnectionError {
        payload: Value,
    },
    Subscribe {
        id: String,
        payload: SubscribePayload,
    },
    Next {
        id: String,
        payload: Value,
    },
    Error {
        id: String,
        payload: Value,
    },
    Complete {
        id: String,
    },
    Pong,
}

#[derive(Debug, Serialize, Deserialize)]
struct SubscribePayload {
    query: String,
    variables: HashMap<String, Value>,
}

pub struct Subscription {
    id: String,
    unsubscribe_tx: mpsc::Sender<String>,
}

impl Subscription {
    pub async fn unsubscribe(self) {
        let _ = self.unsubscribe_tx.send(self.id).await;
    }
}

pub struct GraphQLWSClient {
    url: String,
    token: Arc<Mutex<String>>,
    subscriptions: Arc<Mutex<HashMap<String, SubscriptionCallbacks>>>,
    subscription_counter: Arc<AtomicU32>,
    command_tx: Option<mpsc::Sender<WSCommand>>,
    handle: Option<tokio::task::JoinHandle<()>>,
}

enum WSCommand {
    Subscribe {
        id: String,
        query: String,
        variables: HashMap<String, Value>,
        callbacks: SubscriptionCallbacks,
    },
    Unsubscribe {
        id: String,
    },
    UpdateToken {
        #[allow(dead_code)]
        token: String,
    },
    Disconnect,
}

impl GraphQLWSClient {
    pub fn new(url: String, token: String) -> Self {
        Self {
            url,
            token: Arc::new(Mutex::new(token)),
            subscriptions: Arc::new(Mutex::new(HashMap::new())),
            subscription_counter: Arc::new(AtomicU32::new(0)),
            command_tx: None,
            handle: None,
        }
    }

    pub async fn connect(&mut self) -> Result<(), WinCCError> {
        if self.handle.is_some() {
            println!("WebSocket already connected");
            return Ok(());
        }

        println!("Starting WebSocket connection...");
        let (command_tx, mut command_rx) = mpsc::channel::<WSCommand>(100);
        self.command_tx = Some(command_tx.clone());
        println!("Command channel created");

        let url = self.url.clone();
        let token = self.token.lock().unwrap().clone();
        let subscriptions = self.subscriptions.clone();

        let handle = tokio::spawn(async move {
            let mut connection_ready = false;
            let mut pending_commands = Vec::new();
            // Try with graphql-transport-ws subprotocol using proper request building
            println!("Connecting to WebSocket URL: {}", url);
            
            // Build proper WebSocket request with subprotocol
            use tungstenite::client::IntoClientRequest;
            let mut request = url.into_client_request().expect("Failed to build request");
            request.headers_mut().insert(
                "Sec-WebSocket-Protocol", 
                "graphql-transport-ws".parse().expect("Invalid protocol header")
            );
            
            let (ws_stream, _response) = match connect_async(request).await {
                Ok(result) => {
                    println!("WebSocket handshake successful, status: {}", result.1.status());
                    result
                },
                Err(e) => {
                    eprintln!("WebSocket connection failed: {}", e);
                    return;
                }
            };

            let (mut write, mut read) = ws_stream.split();

            // Send connection init for graphql-transport-ws protocol
            let init_msg = WSMessage::ConnectionInit {
                payload: {
                    let mut payload = HashMap::new();
                    if !token.is_empty() {
                        payload.insert("Authorization".to_string(), format!("Bearer {}", token));
                    }
                    payload
                },
            };

            if let Ok(json) = serde_json::to_string(&init_msg) {
                println!("Sending connection_init: {}", json);
                let _ = write.send(Message::Text(json)).await;
            } else {
                eprintln!("Failed to serialize connection_init message");
                return;
            }

            loop {
                tokio::select! {
                    Some(msg) = read.next() => {
                        match msg {
                            Ok(Message::Text(text)) => {
                                println!("Received WebSocket message: {}", text);
                                if let Ok(ws_msg) = serde_json::from_str::<WSMessage>(&text) {
                                    println!("Parsed message type: {:?}", ws_msg);
                                    match ws_msg {
                                        WSMessage::ConnectionAck => {
                                            println!("WebSocket connection acknowledged - ready for subscriptions");
                                            connection_ready = true;
                                            
                                            // Process any pending subscription commands
                                            for cmd in pending_commands.drain(..) {
                                                if let WSCommand::Subscribe { id, query, variables, callbacks } = cmd {
                                                    println!("Processing pending subscribe command for ID: {}", id);
                                                    subscriptions.lock().unwrap().insert(id.clone(), callbacks);
                                                    
                                                    let subscribe_msg = WSMessage::Subscribe {
                                                        id: id.clone(),
                                                        payload: SubscribePayload { query, variables },
                                                    };
                                                    
                                                    if let Ok(json) = serde_json::to_string(&subscribe_msg) {
                                                        println!("Sending pending subscribe message: {}", json);
                                                        match write.send(Message::Text(json)).await {
                                                            Ok(_) => println!("Pending subscribe message sent successfully"),
                                                            Err(e) => eprintln!("Failed to send pending subscribe message: {}", e),
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        WSMessage::ConnectionError { payload } => {
                                            eprintln!("Connection error: {:?}", payload);
                                            break;
                                        }
                                        WSMessage::Next { id, payload } => {
                                            println!("Received data for subscription {}: {:?}", id, payload);
                                            if let Some(callbacks) = subscriptions.lock().unwrap().get(&id) {
                                                (callbacks.on_data)(payload);
                                            }
                                        }
                                        WSMessage::Error { id, payload } => {
                                            eprintln!("Subscription error for {}: {:?}", id, payload);
                                            if let Some(callbacks) = subscriptions.lock().unwrap().get(&id) {
                                                if let Some(on_error) = &callbacks.on_error {
                                                    (on_error)(payload.to_string());
                                                }
                                            }
                                        }
                                        WSMessage::Complete { id } => {
                                            println!("Subscription {} completed", id);
                                            if let Some(callbacks) = subscriptions.lock().unwrap().remove(&id) {
                                                if let Some(on_complete) = &callbacks.on_complete {
                                                    (on_complete)();
                                                }
                                            }
                                        }
                                        _ => {
                                            println!("Unhandled message type: {:?}", ws_msg);
                                        }
                                    }
                                } else {
                                    eprintln!("Failed to parse WebSocket message: {}", text);
                                }
                            }
                            Ok(Message::Close(close_frame)) => {
                                println!("WebSocket connection closed: {:?}", close_frame);
                                break;
                            }
                            Err(e) => {
                                eprintln!("WebSocket error: {}", e);
                                break;
                            }
                            _ => {
                                println!("Received other message type: {:?}", msg);
                            }
                        }
                    }
                    Some(cmd) = command_rx.recv() => {
                        match cmd {
                            WSCommand::Subscribe { id, query, variables, callbacks } => {
                                println!("Processing subscribe command for ID: {}", id);
                                if !connection_ready {
                                    println!("Connection not ready yet, queuing command...");
                                    pending_commands.push(WSCommand::Subscribe { id, query, variables, callbacks });
                                    continue;
                                }
                                
                                subscriptions.lock().unwrap().insert(id.clone(), callbacks);
                                
                                let subscribe_msg = WSMessage::Subscribe {
                                    id: id.clone(),
                                    payload: SubscribePayload { query, variables },
                                };
                                
                                if let Ok(json) = serde_json::to_string(&subscribe_msg) {
                                    println!("Sending subscribe message: {}", json);
                                    match write.send(Message::Text(json)).await {
                                        Ok(_) => println!("Subscribe message sent successfully"),
                                        Err(e) => eprintln!("Failed to send subscribe message: {}", e),
                                    }
                                } else {
                                    eprintln!("Failed to serialize subscribe message");
                                }
                            }
                            WSCommand::Unsubscribe { id } => {
                                subscriptions.lock().unwrap().remove(&id);
                                
                                let complete_msg = WSMessage::Complete { id };
                                if let Ok(json) = serde_json::to_string(&complete_msg) {
                                    let _ = write.send(Message::Text(json)).await;
                                }
                            }
                            WSCommand::UpdateToken { token: _ } => {
                                // For token update, we'd need to reconnect
                                // This is simplified - in production you'd handle this more gracefully
                                break;
                            }
                            WSCommand::Disconnect => {
                                let _ = write.send(Message::Close(None)).await;
                                break;
                            }
                        }
                    }
                }
            }

            // Clean up subscriptions on disconnect
            for (_, callbacks) in subscriptions.lock().unwrap().iter() {
                if let Some(on_error) = &callbacks.on_error {
                    (on_error)("WebSocket connection closed".to_string());
                }
            }
            subscriptions.lock().unwrap().clear();
        });

        self.handle = Some(handle);

        // Don't wait here - let the connection establish in the background
        Ok(())
    }

    pub async fn subscribe(
        &self,
        query: String,
        variables: HashMap<String, Value>,
        callbacks: SubscriptionCallbacks,
    ) -> Result<Subscription, WinCCError> {
        let id = format!("sub_{}", self.subscription_counter.fetch_add(1, Ordering::SeqCst));
        println!("Creating subscription with ID: {}", id);
        
        if let Some(tx) = &self.command_tx {
            println!("Command channel available, sending subscribe command");
            let (unsubscribe_tx, mut unsubscribe_rx) = mpsc::channel(1);
            
            let cmd_tx = tx.clone();
            let sub_id = id.clone();
            tokio::spawn(async move {
                if let Some(_) = unsubscribe_rx.recv().await {
                    println!("Unsubscribe requested for: {}", sub_id);
                    let _ = cmd_tx.send(WSCommand::Unsubscribe { id: sub_id }).await;
                }
            });

            match tx.send(WSCommand::Subscribe {
                id: id.clone(),
                query,
                variables,
                callbacks,
            })
            .await {
                Ok(_) => {
                    println!("Subscribe command queued successfully");
                    Ok(Subscription { id, unsubscribe_tx })
                }
                Err(e) => {
                    eprintln!("Failed to queue subscribe command: {}", e);
                    Err(WinCCError::OperationFailed("Failed to send subscribe command".to_string()))
                }
            }
        } else {
            eprintln!("WebSocket command channel not available");
            Err(WinCCError::OperationFailed("WebSocket not connected".to_string()))
        }
    }

    pub fn update_token(&self, token: String) {
        *self.token.lock().unwrap() = token.clone();
        
        if let Some(tx) = &self.command_tx {
            let _ = tx.try_send(WSCommand::UpdateToken { token });
        }
    }

    pub async fn disconnect(&mut self) {
        if let Some(tx) = &self.command_tx {
            let _ = tx.send(WSCommand::Disconnect).await;
        }

        if let Some(handle) = self.handle.take() {
            let _ = handle.await;
        }

        self.command_tx = None;
    }
}