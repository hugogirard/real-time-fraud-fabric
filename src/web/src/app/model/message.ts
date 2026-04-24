export enum Role {
    User = 'user',
    Assistant = 'assistant'
}


export interface Message {
    id: string;
    role: Role;
    text: string;
    createdAt: string;
}