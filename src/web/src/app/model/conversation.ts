import { Session } from "./session";

export interface Conversation {
    prompt?: string | null;
    answer?: string | null;
    sessionInfo?: Session | null;
}