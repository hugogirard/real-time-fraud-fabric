import { Injectable } from "@angular/core";
import { Message, Role } from "../model/message";
import { Observable, of, delay } from "rxjs";
import { HttpClient, HttpEvent, HttpEventType } from "@angular/common/http";
import { environment } from "../environments/environment";
import { Conversation } from "../model/conversation";
import { Session } from "../model/session";

@Injectable({
    providedIn: 'root'
})
export class FraudService {

    constructor(private http: HttpClient) {

    }

    askQuestion(prompt: string, sessionInfo: Session | null): Observable<HttpEvent<string>> {

        const conversation: Conversation = {
            prompt: prompt,
            sessionInfo: sessionInfo
        }

        return this.http.post(`${environment.apiBaseUrl}/api/conversation`, conversation, {
            observe: 'events',
            reportProgress: true,
            responseType: 'text'
        });
    }
}