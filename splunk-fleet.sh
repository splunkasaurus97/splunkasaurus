
###---/opt/splunk/etc/shcluster/apps/whateverapp/bin/---##
####--fleet_shared.py--####
import requests
import urllib3
import json
import sys
import splunk.Intersplunk

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
fleetProtocol = 'https'
####--fleetIp = '10.11.12.13'--####
fleetPort = '8080'
###-fleetApiKey = 'r############################################==' # --It's Readonly

def getFleetQueryInfo():
    queryDetails = []
    api_url = f"{fleetProtocol}://{fleetIp}:{fleetPort}/api/v1/fleet/queries"
    headers = {
        "Authorization": f"Bearer {fleetApiKey}",
        "Content-Type": "application/json",
    }
    try:
        response = requests.get(api_url, headers=headers, verify=False)
        data = response.json()
        queries = data['queries']
        for query in queries:
            queryDetails.append({'id':query['id'], 'name': query['name'], 'query': query['query']})
        return queryDetails
    except Exception as e:
        print(e)
        return None

def getFleetHostInfo():
    hostsDict = {'linux': {}, 'windows': {}}
    api_url = f"{fleetProtocol}://{fleetIp}:{fleetPort}/api/v1/fleet/hosts"
    headers = {
        "Authorization": f"Bearer {fleetApiKey}",
        "Content-Type": "application/json",
    }
    try:
        response = requests.get(api_url, headers=headers, verify=False)
        data = response.json()
        hosts = data['hosts']
        for host in hosts:
            if host['platform'] == 'windows':
                hostsDict['windows'][host['id']] = host
            else:
                hostsDict['linux'][host['id']] = host
        return hostsDict
    except Exception as e:
        print(e)
        return None

def runLiveQuery(queryId, targetList, hostsDict):
    totalResultsList = []
    reqData = {
        "query_ids": [queryId],
        "host_ids": targetList
    }
    api_url = f"{fleetProtocol}://{fleetIp}:{fleetPort}/api/v1/fleet/queries/run"
    headers = {
        "Authorization": f"Bearer {fleetApiKey}",
        "Content-Type": "application/json",
    }
    try:
        response = requests.get(api_url, headers=headers, json=reqData, verify=False)
        data = response.json()['live_query_results'][0] #Grab the first query
        for result in data['results']:
            hostId = result['host_id']
            hostName = hostsDict[hostId]['hostname']
            primaryIp = hostsDict[hostId]['primary_ip']
            rows = result['rows']
            for row in rows:
                row['host_id'] = hostId
                row['host_name'] = hostName
                row['primary_ip'] = primaryIp
            totalResultsList.extend(rows)
        return totalResultsList
    except Exception as e:
        print(e)
        return None

def outputHostInfo(hostDict):
    hostInfoList = []
    for hostId in hostDict['linux'].keys():
        host = hostDict['linux'][hostId]
        hostinfo = {'id':host['id'], 'name':host['hostname'], 'platform':'linux', 'platform_name':host['platform'], 'primary_ip':host['primary_ip'], 'status':host['status']}
        hostInfoList.append(hostinfo)
    for hostId in hostDict['windows'].keys():
        host = hostDict['windows'][hostId]
        hostinfo = {'id':host['id'], 'name':host['hostname'], 'platform':'windows', 'platform_name':host['platform'], 'primary_ip':host['primary_ip'], 'status':host['status']}
        hostInfoList.append(hostinfo)
    return hostInfoList

usageMessage = [
    {'Usage': '| fleet_shared query list', 'Description': 'List all available queries.'},
    {'Usage': '| fleet_shared query <query_id> <platform>', 'Description': 'Runs a live query, requires query_id and platform (linux/windows).'},
    {'Usage': '| fleet_shared hosts list', 'Description': 'List all fleet hosts.'}
]

argCount = len(sys.argv) - 1
results = usageMessage

if argCount > 0:
    if sys.argv[1] == 'query':
        if argCount > 1:
            if sys.argv[2] == 'list':
                results = getFleetQueryInfo()
            elif argCount > 2:
                if sys.argv[3] == "linux" or sys.argv[3] == "windows":
                    queryId = int(sys.argv[2])
                    platform = sys.argv[3]
                    hostsDict = getFleetHostInfo()
                    targetIdList = list(hostsDict[platform].keys())
                    results = runLiveQuery(queryId, targetIdList, hostsDict[platform])
    elif sys.argv[1] == 'hosts':
        if argCount > 1:
            if sys.argv[2] == 'list':
                hostsDict = getFleetHostInfo()
                results = outputHostInfo(hostsDict)

splunk.Intersplunk.outputResults(results)