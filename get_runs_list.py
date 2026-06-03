import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/jemytrade2/jemypedia-android/actions/runs')
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read())
        runs = data.get('workflow_runs', [])
        for r in runs[:3]:
            commit_msg = r['head_commit']['message'].split('\n')[0]
            print(f"Run ID: {r['id']}, Status: {r['status']}, Conclusion: {r['conclusion']}, Commit: {commit_msg}")
except Exception as e:
    print('Error:', e)
