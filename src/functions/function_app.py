from services import ChatService
from factory import AgentFactory
from azure.functions import HttpMethod
from azurefunctions.extensions.http.fastapi import Request, StreamingResponse, JSONResponse
from contract import Conversation
import azure.functions as func
import json
import logging
import asyncio

chat_service = ChatService()
agent_factory = AgentFactory()

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

def _extract_token(req: Request) -> str | None:
    auth_header = req.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header[7:]
    return req.headers.get('X-MS-TOKEN-AAD-ACCESS-TOKEN')

@app.route(route="session/new", methods=[HttpMethod.GET])
def new_session(req:Request) -> JSONResponse:
    logging.info("Calling get new session")

    try:

        jwt_token = _extract_token(req)

        if not jwt_token:
            return func.HttpResponse(
                "AAD Access Token not provided",
                status_code=404
            )            

        agent = agent_factory.create_agent(jwt_token)

        session_data = chat_service.create_session(agent=agent)
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
        
        jwt_token = _extract_token(req)

        if not jwt_token:
            return func.HttpResponse(
                "AAD Access Token not provided",
                status_code=404
            )            

        agent = agent_factory.create_agent(jwt_token)

        principal_name = req.headers.get('X-MS-CLIENT-PRINCIPAL-NAME')

        if not principal_name:
            return func.HttpResponse(
                "Principal name not provided",
                status_code=404
            )
        
        req_body = await req.body()
        conversation = Conversation.model_validate_json(req_body)
        
        return StreamingResponse(
            chat_service.run(agent=agent,principal_name=principal_name,conversation=conversation),
            media_type="text/event-stream"
        )
    
    except Exception as err: 
        logging.error(err)
        return func.HttpResponse(
             "Internal Server Error",
             status_code=500
        )     