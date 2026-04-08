from config import Config
from contract import SessionInfo, Conversation
from agent_framework.foundry import FoundryAgent
from agent_framework import AgentSession
from azure.identity.aio import DefaultAzureCredential

class ChatService:
    
    def __init__(self):
        config = Config()
        
        self.agent = FoundryAgent(
            project_endpoint=config.foundry_project_endpoint,
            agent_name=config.foundry_agent_name,
            agent_version=config.foundry_agent_version,
            credential=DefaultAzureCredential()
        )
    
    def create_session(self) -> SessionInfo:
        session = self.agent.create_session()    
        return SessionInfo(
            sessionId=session.session_id,
            serviceSessionId=session.service_session_id
        )
    
    async def run(self, conversation:Conversation) -> Conversation:
        session = self.agent.get_session(service_session_id=conversation.session_info.service_session_id,
                                         session_id=conversation.session_info.session_id)
        # session = AgentSession.from_dict(session_data)
        result = await self.agent.run(conversation.prompt, session=session)
        return Conversation(
            answer=result.text,
            sessionInfo=SessionInfo(
                sessionId=session.session_id,
                serviceSessionId=session.service_session_id
            )
        )
        # return result.text, session.to_dict()