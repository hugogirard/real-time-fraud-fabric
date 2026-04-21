import { Component, effect, signal } from "@angular/core";
import { Chat } from "../../components/chat/chat";
import { Session } from "../../model/session";
import { SessionService } from "../../services/session.service";
import { Loading } from "../../components/loading/loading";
import { StateService } from "../../services/state.service";
import { Constant } from "../../infrastructure/constants";

@Component({
    selector: 'fraud',
    standalone: true,
    templateUrl: './fraud.html',
    styleUrl: './fraud.css',
    imports: [Chat, Loading]
})
export class FraudPage {

    selectedSession = signal<Session | undefined>(undefined);
    isLoading = signal(false);

    constructor(private sessionService: SessionService, private stateService: StateService) {

        effect((onCleanup) => {

            this.isLoading.set(true);
            const sub = this.sessionService.createNewSession().subscribe(session => {
                this.selectedSession.set(session);
                this.stateService.setItem(Constant.SESSION_KEY, session);
                this.isLoading.set(false);
            });
            onCleanup(() => sub.unsubscribe());

        });
    }
}