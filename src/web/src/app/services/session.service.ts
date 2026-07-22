import { Injectable } from "@angular/core";
import { HttpClient } from '@angular/common/http';
import { Session } from '../model/session';
import { Observable, of, delay } from "rxjs";
import { environment } from "../environments/environment";
import { catchError, tap, map } from 'rxjs/operators';

@Injectable({
    providedIn: 'root'
})
export class SessionService {

    constructor(private http: HttpClient) { }

    createNewSession(): Observable<Session> {

        return this.http.get<Session>(`${environment.apiBaseUrl}/api/session/new`)
            .pipe(tap(s => {
                if (!environment.production)
                    console.log(`New SessionId: ${s.sessionId}`);
            }),
                catchError(this.handleError<Session>('createNewSession')));
    }

    /**
     * Handle Http operation that failed.
     * Let the app continue.
     *
     * @param operation - name of the operation that failed
     * @param result - optional value to return as the observable result
     */
    private handleError<T>(operation = 'operation', result?: T) {
        return (error: any): Observable<T> => {

            console.error(error);

            return of(result as T);
        };
    }
}