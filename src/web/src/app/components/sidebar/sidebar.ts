import { Component, output, signal } from "@angular/core";
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

    loadingSession = signal(true);
    sessions = signal<Session[]>([]);
    activeSessions = signal<Session[]>([]);
    resolvedSessions = signal<Session[]>([]);
    selectedSession = signal<Session | undefined>(undefined);

    sessionSelected = output<Session>();

    constructor(private router: Router, private sessionService: SessionService, private stateService: StateService) { }

    ngOnInit() {
        this.getSessions();
    }

    logout() {
        // Implement Entra ID logout
        this.router.navigate(['/'])
    }

    selectSession(session: Session) {
        if (this.selectedSession()?.id == session.id || this.stateService.modelIsAnswering())
            return;

        this.selectedSession.set(session);
        this.sessionSelected.emit(session);
    }

    getSessions() {
        this.sessionService.getSessions().subscribe(sessions => {
            this.loadingSession.set(false);
            this.sessions.set(sessions);
            this.activeSessions.set(sessions.filter(s => !s.resolved));
            this.resolvedSessions.set(sessions.filter(s => s.resolved));

            if (sessions.length > 0) {
                const active = sessions.filter(s => !s.resolved);
                const resolved = sessions.filter(s => s.resolved);
                const firstSession = active.length > 0 ? active[0] : resolved[0];
                this.selectSession(firstSession);
            }
        });
    }
}