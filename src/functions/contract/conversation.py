from pydantic import BaseModel, Field
from .session_info import SessionInfo
from typing import Optional

class Conversation(BaseModel):
    prompt:Optional[str] = None
    answer:Optional[str] = None
    session_info:SessionInfo = Field(...,alias="sessionInfo")