import { Component, Output, EventEmitter } from "@angular/core";
import { Router } from "@angular/router";
import { SessionService } from "../../services/session.service";
import { Session } from "../../model/session";
import { StateService } from "../../services/state.service";
import { NgClass } from "@angular/common";
import { SessionComponent } from "../session/session";


@Component({
    selector: 'sidebar',
    templateUrl: './sidebar.html',
    styleUrl: './sidebar.css',
    imports: [NgClass, SessionComponent]
})
export class SideBar {

    loadingSession: boolean = true;
    sessions: Array<Session> = [];
    activeSessions: Array<Session> = [];
    resolvedSessions: Array<Session> = [];
    selectedSession?: Session;

    @Output() sessionSelected = new EventEmitter<Session>();

    constructor(private router: Router, private sessionService: SessionService, private stateService: StateService) { }

    ngOnInit() {
        this.getSessions();
    }

    logout() {
        // Implement Entra ID logout
        this.router.navigate(['/'])
    }

    selectSession(session: Session) {
        if (this.selectedSession?.id == session.id || this.selectedSession || this.stateService.modelIsAnswering)
            return;

        this.selectedSession = session;
        this.sessionSelected.emit(session);
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