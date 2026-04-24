import { Component, DestroyRef, inject, signal } from "@angular/core";
import { Chat } from "../../components/chat/chat";
import { Session } from "../../model/session";
import { SessionService } from "../../services/session.service";
import { Loading } from "../../components/loading/loading";
import { StateService } from "../../services/state.service";
import { Constant } from "../../infrastructure/constants";
import { takeUntilDestroyed } from "@angular/core/rxjs-interop";
import { MessageStore } from "../../stores/message.store";

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

    constructor(private messageStore: MessageStore) {
    }

    ngOnInit() {
        this.isLoading.set(true);
        this.messageStore.newSession().subscribe({
            next: () => this.isLoading.set(false),
            error: () => this.isLoading.set(false)
        });
    }
}