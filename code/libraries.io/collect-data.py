import os
import requests
import json
from pathlib import Path
import pandas as pd
import time
from datetime import datetime, timedelta
from typing import List, Dict
from urllib.parse import quote

# Global variables to manage API keys and their request counts
_API_KEYS: List[str] = []
_KEY_USAGE: Dict[str, int] = {}  # Counts per key
_KEY_LAST_RESET: Dict[str, datetime] = {}  # Last reset time per key
_CURRENT_KEY_INDEX = 0
_REQUESTS_PER_MINUTE = 60

def load_api_keys():
    """Load Libraries.io API keys from a text file"""
    global _API_KEYS
    try:
        with open('api_keys.txt', 'r') as f:
            _API_KEYS = [line.strip() for line in f if line.strip()]
        if not _API_KEYS:
            raise ValueError("No API keys found in api_keys.txt")
        # Initialize usage tracking for each key
        for key in _API_KEYS:
            _KEY_USAGE[key] = 0
            _KEY_LAST_RESET[key] = datetime.now()
    except FileNotFoundError:
        raise ValueError("api_keys.txt file not found")

def get_api_key():
    """Get an available API key considering rate limits"""
    global _CURRENT_KEY_INDEX
    
    if not _API_KEYS:
        load_api_keys()
    
    current_time = datetime.now()
    
    # Try all keys until finding one that hasn't hit rate limit
    attempts = 0
    while attempts < len(_API_KEYS):
        key = _API_KEYS[_CURRENT_KEY_INDEX]
        
        # Reset counter if a minute has passed
        if (current_time - _KEY_LAST_RESET[key]).seconds >= 60:
            _KEY_USAGE[key] = 0
            _KEY_LAST_RESET[key] = current_time
        
        # Check if current key has available requests
        if _KEY_USAGE[key] < _REQUESTS_PER_MINUTE:
            _KEY_USAGE[key] += 1
            return key
            
        # Try next key
        _CURRENT_KEY_INDEX = (_CURRENT_KEY_INDEX + 1) % len(_API_KEYS)
        attempts += 1
    
    # If all keys are rate-limited, wait until the first key's counter resets
    sleep_time = 60 - (current_time - _KEY_LAST_RESET[_API_KEYS[0]]).seconds
    time.sleep(sleep_time)
    return get_api_key()

def get_project_info(platform, package_name):
    """
    Retrieve project information from Libraries.io API
    
    Args:
        platform (str): The package manager/platform name (e.g., 'npm', 'pypi')
        package_name (str): The name of the package
    
    Returns:
        dict: Project information or None if request fails
    """
    # Check if cache file exists
    cache_dir = Path("../../data/libraries/project")
    cache_file = cache_dir / f"{platform}_{package_name}.json"
    if cache_file.exists():
        return {'d': "a"} # dummy return value

    api_key = get_api_key()
    base_url = "https://libraries.io/api"
    endpoint = f"{base_url}/{platform}/{package_name}"
    
    params = {
        'api_key': api_key
    }
    
    try:
        response = requests.get(endpoint, params=params)
        response.raise_for_status()
        
        # Create data directory if it doesn't exist
        cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Save to cache file
        with open(cache_file, 'w') as f:
            json.dump(response.json(), f, indent=2)
            
        return response.json()
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching project info: {e}")
        return None

# Example usage:
# project_info = get_project_info('npm', 'lodash')
# if project_info:
#     print(f"Name: {project_info.get('name')}")
#     print(f"Description: {project_info.get('description')}")

def get_project_dependencies(platform, package_name, version='latest'):
    """
    Retrieve project dependencies from Libraries.io API
    
    Args:
        platform (str): The package manager/platform name (e.g., 'npm', 'pypi')
        package_name (str): The name of the package
        version (str): Package version (default: 'latest')
    
    Returns:
        dict: Project dependencies or None if request fails
    """
    # Check if cache file exists
    cache_dir = Path("../../data/libraries/dependencies")
    cache_file = cache_dir / f"{platform}_{package_name}_{version}_dependencies.json"
    if cache_file.exists():
        return {'d': "a"} # dummy return value

    api_key = get_api_key()
    base_url = "https://libraries.io/api"
    endpoint = f"{base_url}/{platform}/{package_name}/{version}/dependencies"
    
    params = {
        'api_key': api_key
    }
    
    try:
        response = requests.get(endpoint, params=params)
        response.raise_for_status()
        
        # Create data directory if it doesn't exist
        cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Save to cache file
        with open(cache_file, 'w') as f:
            json.dump(response.json(), f, indent=2)
            
        return response.json()
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching dependencies: {e}")
        return None
    
def process_mttu_data():
    """
    Process MTTU data and collect Libraries.io information for each package
    """

    try:
        # Load CSV file
        df = pd.read_csv('../../data/mttu/mttu.csv')
        total_rows = len(df)
        
        # Process each row
        for index, row in df.iterrows():
            platform = row['system_name']
            package_name = row['from_package_name'].replace('/', '%2F')
            
            # Print progress
            print(f"Processing {index + 1}/{total_rows}: {platform}/{package_name}")
            
            # Get project info
            project_info = get_project_info(platform, package_name)
            
            # Get dependencies
            dependencies = get_project_dependencies(platform, package_name)
            
            if not project_info or not dependencies:
                print(f"Failed to fetch data for {platform}/{package_name}")
                
    except FileNotFoundError:
        print("MTTU CSV file not found")
    except Exception as e:
        print(f"Error processing MTTU data: {e}")

if __name__ == '__main__':
    process_mttu_data()