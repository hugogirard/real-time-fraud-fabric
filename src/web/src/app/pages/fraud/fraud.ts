import { Component, DestroyRef, inject, signal } from "@angular/core";
import { Chat } from "../../components/chat/chat";
import { Session } from "../../model/session";
import { SessionService } from "../../services/session.service";
import { Loading } from "../../components/loading/loading";
import { StateService } from "../../services/state.service";
import { Constant } from "../../infrastructure/constants";
import { takeUntilDestroyed } from "@angular/core/rxjs-interop";

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

    private destroyRef = inject(DestroyRef);

    constructor(private sessionService: SessionService, private stateService: StateService) {
    }

    ngOnInit() {
        this.isLoading.set(true);
        this.sessionService.createNewSession()
            .pipe(takeUntilDestroyed(this.destroyRef))
            .subscribe(session => {
                this.selectedSession.set(session);
                this.stateService.setItem(Constant.SESSION_KEY, session);
                this.isLoading.set(false);
            });
    }
}