import { Component, input, signal, effect, computed } from "@angular/core";
import { DatePipe } from "@angular/common";
import { FraudService } from "../../services/fraud.service";
import { Message, Role } from "../../model/message";
import { Session } from "../../model/session";
import { Loading } from "../loading/loading";
import { MsalService } from "@azure/msal-angular";



@Component({
    selector: 'chat-pane',
    standalone: true,
    styleUrl: './chat.css',
    templateUrl: './chat.html',
    imports: [DatePipe, Loading]
})
export class Chat {

    session = input<Session>();
    private readonly welcomeMessage: Message = {
        id: 'welcome',
        role: Role.Assistant,
        text: 'Hi, I am the assistant for Fraud Detection at Contoso Bank. How can I help you today?',
        createdAt: new Date().toISOString()
    };
    messages = signal<Message[]>([]);
    isLoading = signal(false);
    isTyping = signal(false);
    username: string | null = null;
    initial: string | null = null;

    readonly loadingTitle = 'Loading conversation';
    Role = Role;

    constructor(private fraudService: FraudService, private authService: MsalService) {

        effect((onCleanup) => {
            const s = this.session();
            if (s && s.sessionId != '') {
                // Set default message but show ... like someone is typing
                this.isTyping.set(true);
                const timer = setTimeout(() => {
                    this.isTyping.set(false);
                    this.messages.set([this.welcomeMessage]);
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
}