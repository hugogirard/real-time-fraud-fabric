import { Component, input, signal, effect, computed } from "@angular/core";
import { Message, Role } from "../../model/message";
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
    messages = signal<Message[]>([]);
    isLoading = signal(false);
    isTyping = signal(false);
    username: string | null = null;
    initial: string | null = null;
    userMessage = signal('');

    readonly loadingTitle = 'Loading conversation';
    Role = Role;

    constructor(public messageStore: MessageStore, private authService: MsalService) {

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