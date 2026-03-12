import { Component, signal } from "@angular/core";
import { SideBar } from "../../components/sidebar/sidebar";
import { Chat } from "../../components/chat/chat";
import { Session } from "../../model/session";

@Component({
    selector: 'fraud',
    standalone: true,
    templateUrl: './fraud.html',
    styleUrl: './fraud.css',
    imports: [SideBar, Chat]
})
export class FraudPage {
    selectedSession = signal<Session | undefined>(undefined);

    onSessionSelected(session: Session) {
        this.selectedSession.set(session);
    }
}