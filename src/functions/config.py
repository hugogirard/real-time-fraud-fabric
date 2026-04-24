import os

class Config:

    @property
    def foundry_project_endpoint(self) -> str:
        return os.getenv('FOUNDRY_PROJECT_ENDPOINT')
    
    @property
    def foundry_agent_name(self) -> str:
        return os.getenv('FOUNDRY_AGENT_NAME')
    
    @property
    def foundry_agent_version(self) -> str:
        return os.getenv('FOUNDRY_AGENT_VERSION')

    @property
    def identity_client_id(self) -> str:
        return os.getenv('AZURE_CLIENT_ID')