#!/usr/bin/env python3
"""
Example usage of WinCC Unified Python Client Library
Demonstrates basic functionality similar to the JavaScript examples
"""

import asyncio
import logging
import os
from winccunified_client import WinCCUnifiedClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    # Configuration - get URLs and credentials from environment variables or use defaults
    HTTP_URL = os.getenv("GRAPHQL_HTTP_URL", "https://your-wincc-server/graphql")
    WS_URL = os.getenv("GRAPHQL_WS_URL", "wss://your-wincc-server/graphql")
    USERNAME = os.getenv("GRAPHQL_USERNAME", "username")
    PASSWORD = os.getenv("GRAPHQL_PASSWORD", "password")
    
    # Initialize client
    client = WinCCUnifiedClient(HTTP_URL, WS_URL)
    
    try:
        async with client:
            # Login
            print("Logging in...")
            session = await client.login(USERNAME, PASSWORD)
            print(f"Logged in as: {session['user']['name']}")
            print(f"Token expires: {session['expires']}")
            
            # Get session info
            print("\nGetting session info...")
            session_info = await client.get_session()
            
            if not session_info:
                print("No session info found")
                
            elif isinstance(session_info, list):
                print("All sessions info:")
                for s_info in session_info:
                    print(f"  - User: {s_info['user']['fullName']}, Expires: {s_info['expires']}")
            else:
                print("Session info:")
           
            # Browse available objects
            print("\nBrowsing available objects...")
            objects = await client.browse()
            print(f"Found {len(objects)} objects")
            for obj in objects[:5]:  # Show first 5 objects
                print(f"  - {obj['name']} ({obj['objectType']})")
            
            # Get tag values
            print("\nGetting tag values...")
            tag_names = ["HMI_Tag_1", "HMI_Tag_2"]  # Replace with actual tag names
            try:
                tags = await client.get_tag_values(tag_names)
                for tag in tags:
                    if tag.get('error'):
                        print(f"  - {tag['name']}: ERROR - {tag['error']['description']}")
                    else:
                        value = tag['value']['value']
                        timestamp = tag['value']['timestamp']
                        quality = tag['value']['quality']['quality']
                        print(f"  - {tag['name']}: {value} (Quality: {quality}, Time: {timestamp})")
            except Exception as e:
                print(f"Error getting tag values: {e}")
            
            # Get logged tag values
            print("\nGetting logged tag values...")
            try:
                from datetime import datetime, timedelta
                
                # Get values from the last 24 hours
                end_time = datetime.now()
                start_time = end_time - timedelta(hours=24)
                
                logged_values = await client.get_logged_tag_values(
                    names=["PV-Vogler-PC::Meter_Input_WattAct:LoggingTag_1"],
                    start_time=start_time.isoformat() + "Z",
                    end_time=end_time.isoformat() + "Z",
                    max_number_of_values=10
                )
                print(f"Found {len(logged_values)} logged tag results")
                for result in logged_values:
                    if result.get('error') and result.get('error').get('code') != '0':
                        print(f"  - {result['loggingTagName']}: ERROR - {result['error']['description']}")

                    values = result.get('values', [])
                    print(f"  - {result['loggingTagName']}: {len(values)} values")
                    for value in values[-5:]:  # Show last 5 values
                        value = value.get('value', {})
                        timestamp = value['timestamp']
                        val = value['value']
                        quality = value['quality']['quality']
                        print(f"    {timestamp}: {val} (Quality: {quality})")
                            
            except Exception as e:
                print(f"Error getting logged tag values: {e}")
            
            # Get active alarms
            print("\nGetting active alarms...")
            try:
                alarms = await client.get_active_alarms()
                print(f"Found {len(alarms)} active alarms")
                for alarm in alarms[:3]:  # Show first 3 alarms
                    print(f"  - {alarm['name']}: {alarm['eventText']} (Priority: {alarm['priority']})")
            except Exception as e:
                print(f"Error getting alarms: {e}")
            
            # Example of writing tag values
            print("\nWriting tag values...")
            try:
                write_result = await client.write_tag_values([
                    {"name": "HMI_Tag_1", "value": 100},
                    {"name": "HMI_Tag_2", "value": 200}
                ])
                for result in write_result:
                    if result.get('error'):
                        print(f"  - {result['name']}: ERROR - {result['error']['description']}")
                    else:
                        print(f"  - {result['name']}: Written successfully")
            except Exception as e:
                print(f"Error writing tag values: {e}")
            
            # Set up subscription for tag values
            print("\nSetting up tag value subscription...")
            subscription_active = True
            
            async def on_tag_data(data):
                # Handle case where data might be passed as string
                if isinstance(data, str):
                    print(f"  [SUBSCRIPTION] Received string data: {data}")
                    return
                
                # Ensure data is a dictionary before accessing it
                if not isinstance(data, dict):
                    print(f"  [SUBSCRIPTION] Unexpected data type: {type(data)}")
                    return
                    
                tag_data = data.get('data', {})
                if tag_data.get('tagValues'):
                    tag = tag_data['tagValues'] # This is not an array
                    value = tag['value']['value']
                    timestamp = tag['value']['timestamp']
                    reason = tag.get('notificationReason', 'UPDATE')
                    print(f"  [SUBSCRIPTION] {tag['name']}: {value} ({reason}) at {timestamp}")
            
            async def on_tag_error(error):
                print(f"  [SUBSCRIPTION ERROR] {error}")
            
            async def on_tag_complete():
                print("  [SUBSCRIPTION] Tag subscription completed")
            
            try:
                subscription = await client.subscribe_to_tag_values(
                    tag_names,
                    on_data=on_tag_data,
                    on_error=on_tag_error,
                    on_complete=on_tag_complete
                )
                
                print("Tag subscription active. Waiting for updates...")
                
                # Keep subscription active for 30 seconds
                await asyncio.sleep(30)
                
                # Unsubscribe
                print("Unsubscribing from tag values...")
                subscription['unsubscribe']()
                
            except Exception as e:
                print(f"Error setting up subscription: {e}")
            
            # Set up subscription for active alarms
            print("\nSetting up alarm subscription...")
            
            async def on_alarm_data(data):
                # Handle case where data might be passed as string
                if isinstance(data, str):
                    print(f"  [ALARM] Received string data: {data}")
                    return
                    
                # Check if data has the expected structure
                if isinstance(data, dict) and data.get('data', {}).get('activeAlarms'):
                    alarm = data['data']['activeAlarms']
                    reason = alarm.get('notificationReason', 'UPDATE')
                    state = alarm.get('state', 'UNKNOWN')
                    alarm_texts = alarm.get('eventText', [''])
                    alarm_text = alarm_texts[0] if alarm_texts else ''
                    print(f"  [ALARM] {alarm['name']}: {alarm_text} - State: {state} ({reason})")
            
            async def on_alarm_error(error):
                print(f"  [ALARM ERROR] {error}")
            
            try:
                alarm_subscription = await client.subscribe_to_active_alarms(
                    on_data=on_alarm_data,
                    on_error=on_alarm_error
                )
                
                print("Alarm subscription active. Waiting for updates...")
                
                # Keep subscription active for 30 seconds
                await asyncio.sleep(30)
                
                # Unsubscribe
                print("Unsubscribing from alarms...")
                alarm_subscription['unsubscribe']()
                
            except Exception as e:
                print(f"Error setting up alarm subscription: {e}")
            
            # Logout
            print("\nLogging out...")
            await client.logout()
            print("Logged out successfully")
            
    except Exception as e:
        print(f"Error: {e}")
        logger.exception("Application error")

if __name__ == "__main__":
    print("WinCC Unified Python Client Example")
    print("=" * 40)
    
    # Note: You'll need to set environment variables or update credentials
    print("Note: Please set GRAPHQL_HTTP_URL, GRAPHQL_WS_URL, GRAPHQL_USERNAME, and GRAPHQL_PASSWORD environment variables or update values in the script before running")
    print()
    
    asyncio.run(main())