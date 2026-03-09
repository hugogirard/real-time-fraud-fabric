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
    sessions: Array<Session> = []

    constructor(private router: Router, private sessionService: SessionService) { }

    ngOnInit() {
        this.getSessions();
    }

    logout() {
        // Implement Entra ID logout
        this.router.navigate(['/'])
    }

    getSessions() {
        this.sessionService.getSessions().subscribe(sessions => {
            this.loadingSession = false;
            this.sessions = sessions;
        });
    }
}