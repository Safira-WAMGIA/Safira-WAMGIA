from fastapi import FastAPI
app = FastAPI()
@app.get('/healthz', include_in_schema=False)
def healthz():
    return {'status': 'ok'}
@app.get('/')
def root():
    return {'msg': '🚀 Safira service booting!'}
