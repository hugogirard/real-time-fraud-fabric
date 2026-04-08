from typing import Optional
from pydantic import BaseModel, Field

class SessionInfo(BaseModel):
    session_id:str = Field(...,alias="sessionId")
    service_session_id:Optional[str] = Field(None,alias="serviceSessionId")