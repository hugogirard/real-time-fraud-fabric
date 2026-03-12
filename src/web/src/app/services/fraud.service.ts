import { Injectable } from "@angular/core";
import { Message, Role } from "../model/message";
import { Observable, of, delay } from "rxjs";

@Injectable({
    providedIn: 'root'
})
export class FraudService {

    private botResponses = [
        "Thank you for that information. Let me look into this for you right away.",
        "I understand your concern. We take fraud very seriously at Contoso Bank. Let me check the details.",
        "I've flagged this for our fraud investigation team. You should hear back within 24 hours.",
        "Your card has been secured. No further unauthorized transactions can be made.",
        "I've updated your case file. Is there anything else you'd like to know?",
        "For your security, I recommend changing your online banking password as well.",
        "A provisional credit has been applied to your account while we investigate.",
        "Our records show this merchant has been flagged before. We're escalating this case."
    ];

    private conversation: Message[] = [
        { id: 'm1', role: Role.Assistant, text: 'Hello John, we detected a suspicious transaction of **$249.99** at ElectroMart on your card ending in 4921. Did you authorize this transaction?', createdAt: '2026-03-07T09:32:00.000Z' },
        { id: 'm2', role: Role.User, text: "No, I didn't make that purchase.", createdAt: '2026-03-07T09:32:30.000Z' },
        { id: 'm3', role: Role.Assistant, text: 'Thank you for confirming. We have temporarily blocked your card ending in 4921 and flagged this transaction for investigation. A new card will be shipped to your registered address within 3-5 business days.', createdAt: '2026-03-07T09:33:00.000Z' },
        { id: 'm4', role: Role.User, text: 'Okay, thank you for the quick response.', createdAt: '2026-03-07T09:33:15.000Z' },
        { id: 'm5', role: Role.Assistant, text: "You're welcome! Your case reference is **#FR-20260307-001**. Is there anything else I can help you with?", createdAt: '2026-03-07T09:33:30.000Z' },
        { id: 'm6', role: Role.User, text: "No, that's all.", createdAt: '2026-03-07T09:33:50.000Z' },
        { id: 'm7', role: Role.Assistant, text: 'Thank you, John. Stay safe! This session is now resolved.', createdAt: '2026-03-07T09:34:00.000Z' },
    ];

    private responseIndex = 0;

    getMessages(sessionId: string): Observable<Message[]> {
        return of(this.conversation).pipe(delay(3000));
    }

    askQuestion(prompt: string): Observable<Message> {
        const message: Message = {
            id: `m${Date.now() + 1}`,
            role: Role.Assistant,
            text: this.botResponses[this.responseIndex % this.botResponses.length],
            createdAt: new Date(Date.now() + 1500).toISOString()
        }
        return of(message).pipe(delay(2000));
    }
}