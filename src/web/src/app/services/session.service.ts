import { Injectable } from "@angular/core";
import { Session } from '../model/session';
import { Observable, of, delay } from "rxjs";

@Injectable({
    providedIn: 'root'
})
export class SessionService {
    createNewSession(): Observable<Session> {
        const session: Session = {
            sessionId: '1',
            serviceSessionId: null
        }
        return of(session).pipe(delay(2000));
    }
}