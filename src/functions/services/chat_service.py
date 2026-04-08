from config import Config
from agent_framework import Agent
from agent_framework.foundry import FoundryAgent
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
    
    def create_session(self) -> str:
        session = self.agent.create_session()
        return session.session_id
    
    async def run(self,prompt:str) -> str:
        result = await self.agent.run(prompt)
        return result.text