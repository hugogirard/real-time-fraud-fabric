import { Injectable } from "@angular/core";
import { Session } from '../model/session';
import { Observable, of, delay } from "rxjs";

@Injectable({
    providedIn: 'root'
})
export class SessionService {
    getSessions(): Observable<Session[]> {
        const sessions = [
            {
                id: '1',
                title: 'Fraud Alert – $352.00 at GlobalShop Online',
                resolved: false,
                created: '2026-03-09'
            },
            {
                id: '2',
                title: 'Fraud Alert – $249.99 at ElectroMart',
                resolved: true,
                created: '2026-03-07'
            },
            {
                id: '3',
                title: 'Fraud Alert – $89.00 at TravelBooker',
                resolved: true,
                created: '2026-03-05'
            },
            {
                id: '4',
                title: 'Fraud Alert – $1,200.00 at LuxuryGoods',
                resolved: true,
                created: '2026-02-28'
            }
        ];

        return of(sessions);
    }
}