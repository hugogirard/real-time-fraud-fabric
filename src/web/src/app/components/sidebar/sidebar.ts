import { Component } from "@angular/core";
import { Router } from "@angular/router";
import { SessionService } from "../../services/session.service";
import { Session } from "../../model/session";


@Component({
    selector: 'sidebar',
    templateUrl: './sidebar.html',
    styleUrl: './sidebar.css'
})
export class SideBar {

    loadingSession: boolean = true;
    sessions: Array<Session> = [];
    activeSessions: Array<Session> = [];
    resolvedSessions: Array<Session> = [];

    constructor(private router: Router, private sessionService: SessionService) { }

    ngOnInit() {
        this.getSessions();
    }

    logout() {
        // Implement Entra ID logout
        this.router.navigate(['/'])
    }

    selectSession(session: Session) {
        // TODO: implement conversation selection
    }

    getSessions() {
        this.sessionService.getSessions().subscribe(sessions => {
            this.loadingSession = false;
            this.sessions = sessions;
            this.activeSessions = sessions.filter(s => !s.resolved);
            this.resolvedSessions = sessions.filter(s => s.resolved);
        });
    }
}