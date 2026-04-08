from services import ChatService
from azure.functions import HttpMethod
from contract import Conversation
import azure.functions as func
import json
import logging

chat_service = ChatService()

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="session/new", methods=[HttpMethod.GET])
def new_session(req:func.HttpRequest) -> func.HttpResponse:
    logging.info("Calling get new session")

    try:
        session_data = chat_service.create_session()
        return func.HttpResponse(
            body=session_data.model_dump_json(indent=4),
            mimetype="application/json",
            status_code=200
        )
    except Exception as err:
        logging.error(err)
        return func.HttpResponse(
             "Internal Server Error",
             status_code=500
        )        

@app.route(route="conversation",methods=[HttpMethod.POST])
async def run(req: func.HttpRequest) -> func.HttpResponse:

    logging.info('Run conversation')
    
    try:
        
        req_body = req.get_json()
        conversation = Conversation(**req_body)

        result = await chat_service.run(conversation=conversation)
        # conversation = conversation
        # prompt = req_body.get('prompt')
        # session_data = req_body.get('session')

        # if not prompt:
        #     return func.HttpResponse(
        #         "The prompt is not present in the body",
        #         status_code=404
        #     )
        
        # if not session_data:
        #     return func.HttpResponse(
        #         "The session is not present in the body",
        #         status_code=404
        #     )
        
        # answer, updated_session = await chat_service.run(prompt=prompt, session_data=session_data)

        return func.HttpResponse(
            body=result.model_dump_json(indent=4),
            mimetype="application/json",
            status_code=200
        )
    
    except Exception as err: 
        logging.error(err)
        return func.HttpResponse(
             "Internal Server Error",
             status_code=500
        )