export enum Role {
    User = 1,
    Assistant = 2
}


export interface Message {
    id: string;
    role: Role;
    text: string;
    createdAt: string;
}