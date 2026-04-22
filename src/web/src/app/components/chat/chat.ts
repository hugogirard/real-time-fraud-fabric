import { Component, input, signal, effect, afterRenderEffect } from "@angular/core";
import { Session } from "../../model/session";
import { Loading } from "../loading/loading";
import { MsalService } from "@azure/msal-angular";
import { MessageStore } from "../../stores/message.store";
import { RemarkModule } from "ngx-remark";



@Component({
    selector: 'chat-pane',
    standalone: true,
    styleUrl: './chat.css',
    templateUrl: './chat.html',
    imports: [Loading, RemarkModule]
})
export class Chat {

    session = input<Session>();
    isLoading = signal(false);
    isTyping = signal(false);
    username: string | null = null;
    initial: string | null = null;
    userMessage = signal('');

    readonly loadingTitle = 'Loading conversation';

    constructor(public messageStore: MessageStore, private authService: MsalService) {

        // Auto-scroll chat to bottom: tracks messages() and streamingContent() signals,
        // then runs after DOM update to keep the latest content visible.
        afterRenderEffect(() => {
            this.messageStore.messages();
            this.messageStore.streamingContent();
            const el = document.getElementById('chat-messages');
            if (el) el.scrollTop = el.scrollHeight;
        });

        effect((onCleanup) => {
            const s = this.session();
            if (s && s.sessionId != '') {
                // Set default message but show ... like someone is typing
                this.isTyping.set(true);
                const timer = setTimeout(() => {
                    this.isTyping.set(false);
                    this.messageStore.addWelcomeMessage();
                }, 2000);
                onCleanup(() => clearTimeout(timer));
            }
        });
    }

    onNewChat() {
        this.messageStore.newChat();
    }

    ngOnInit() {
        this.username = this.authService.instance.getActiveAccount()?.name ?? null;

        if (this.username) {
            const elements = this.username.split(' ');
            if (elements.length >= 2) {
                const firstLetter = elements[0][0];
                const lastLetter = elements[elements.length - 1][0];
                this.initial = `${firstLetter}${lastLetter}`
            }
        }
    }

    onSend() {
        if (!this.messageStore.isStreaming()) {
            this.messageStore.sendMessage(this.userMessage());
            this.userMessage.set('');;
        }
    }
}