import json
with open('library-management-system-2026.postman_collection.json', 'r', encoding='utf-8') as f:
    d = json.load(f)
lines = []
for x in d.get('item', []):
    if 'item' in x:
        for i in x['item']:
            if 'request' in i and 'url' in i['request']:
                try:
                    url = i['request']['url']['raw']
                    method = i['request']['method']
                    name = i['name']
                    lines.append(f"{name} | {method} {url}")
                except Exception as e:
                    pass
with open('endpoints.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
