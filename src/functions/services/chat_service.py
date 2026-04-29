from config import Config
from contract import SessionInfo, Conversation
from agent_framework.foundry import FoundryAgent
from agent_framework import AgentSession, Agent, AgentRunInputs
from azure.identity.aio import DefaultAzureCredential, OnBehalfOfCredential
import json
import logging

class ChatService:
    
    def __init__(self):
        self.config = Config()
            
    def create_session(self,agent:FoundryAgent) -> SessionInfo:

        session = agent.create_session()

        return SessionInfo(
            sessionId=session.session_id,
            serviceSessionId=session.service_session_id
        )
    
    async def run(self,agent:FoundryAgent,principal_name: str, conversation: Conversation):

        try:
            session = agent.get_session(service_session_id=conversation.session_info.service_session_id,                                         
                                        session_id=conversation.session_info.session_id)
            
            logging.info(f"Starting agent.run for session {session.session_id}")

            payload = json.dumps({ 'username': principal_name, 'prompt': conversation.prompt })

            async for update in agent.run(payload, session=session, stream=True):
                logging.info(f"Got update: {update}")
                if update.text:
                    yield json.dumps({"type": "content", "text": update.text})

            session_info = SessionInfo(
                sessionId=session.session_id,
                serviceSessionId=session.service_session_id
            )
            yield json.dumps({"type": "session_info", **json.loads(session_info.model_dump_json(by_alias=True))})
        except Exception as e:
            logging.error(f"Streaming error: {e}")
            yield json.dumps({"type": "error", "text": str(e)})
         