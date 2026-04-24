from services import ChatService
from azure.functions import HttpMethod
from azurefunctions.extensions.http.fastapi import Request, StreamingResponse, JSONResponse
from contract import Conversation
import azure.functions as func
import json
import logging
import asyncio

chat_service = ChatService()

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="identity", methods=[HttpMethod.GET])
def get_identity(req:Request) -> JSONResponse:
    
    try:
        principal_id = req.headers.get('X-MS-CLIENT-PRINCIPAL-NAME')
        return JSONResponse(
            content=principal_id,
            status_code=200
        )
    except Exception as err:
        logging.error(err)
        return JSONResponse(content={"error": "Internal Server Error"}, status_code=500)   

@app.route(route="session/new", methods=[HttpMethod.GET])
def new_session(req:Request) -> JSONResponse:
    logging.info("Calling get new session")

    try:
        session_data = chat_service.create_session()
        return JSONResponse(
            content=json.loads(session_data.model_dump_json(indent=4,by_alias=True)),
            status_code=200
        )        
    except Exception as err:
        logging.error(err)
        return JSONResponse(content={"error": "Internal Server Error"}, status_code=500)    

@app.route(route="conversation",methods=[HttpMethod.POST])
async def run(req: Request) -> StreamingResponse:

    logging.info('Run conversation')
    
    try:
        
        req_body = await req.body()
        conversation = Conversation.model_validate_json(req_body)

        return StreamingResponse(
            chat_service.run(conversation=conversation),
            media_type="text/event-stream"
        )
    
    except Exception as err: 
        logging.error(err)
        return func.HttpResponse(
             "Internal Server Error",
             status_code=500
        )     