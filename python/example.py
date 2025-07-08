#!/usr/bin/env python3
"""
Example usage of WinCC Unified Python Client Library
Demonstrates basic functionality similar to the JavaScript examples
"""

import asyncio
import logging
from winccunified_client import WinCCUnifiedClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    # Configuration - adjust these URLs to match your WinCC Unified server
    HTTP_URL = "https://your-wincc-server/graphql"
    WS_URL = "wss://your-wincc-server/graphql"
    
    # Initialize client
    client = WinCCUnifiedClient(HTTP_URL, WS_URL)
    
    try:
        async with client:
            # Login
            print("Logging in...")
            session = await client.login("username", "password")
            print(f"Logged in as: {session['user']['name']}")
            print(f"Token expires: {session['expires']}")
            
            # Get session info
            print("\nGetting session info...")
            session_info = await client.get_session()
            print(f"Current user: {session_info['user']['fullName']}")
            
            # Browse available objects
            print("\nBrowsing available objects...")
            objects = await client.browse()
            print(f"Found {len(objects)} objects")
            for obj in objects[:5]:  # Show first 5 objects
                print(f"  - {obj['name']} ({obj['objectType']})")
            
            # Get tag values
            print("\nGetting tag values...")
            tag_names = ["Tag1", "Tag2", "Tag3"]  # Replace with actual tag names
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
                    {"name": "Tag1", "value": "100"},
                    {"name": "Tag2", "value": "200"}
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
                if data.get('data', {}).get('tagValues'):
                    for tag in data['data']['tagValues']:
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
                if data.get('data', {}).get('activeAlarms'):
                    for alarm in data['data']['activeAlarms']:
                        reason = alarm.get('notificationReason', 'UPDATE')
                        print(f"  [ALARM] {alarm['name']}: {alarm['eventText']} ({reason})")
            
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
    
    # Note: You'll need to update the URLs and credentials above
    print("Note: Please update the server URLs and credentials in the script before running")
    print()
    
    asyncio.run(main())