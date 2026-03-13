import { Component, input, signal, effect, computed } from "@angular/core";
import { DatePipe } from "@angular/common";
import { FraudService } from "../../services/fraud.service";
import { Message, Role } from "../../model/message";
import { Session } from "../../model/session";
import { Loading } from "../loading/loading";



@Component({
    selector: 'chat-pane',
    standalone: true,
    styleUrl: './chat.css',
    templateUrl: './chat.html',
    imports: [DatePipe, Loading]
})
export class Chat {

    session = input<Session>();
    messages = signal<Message[]>([]);
    isLoading = signal(false);
    readonly loadingTitle = 'Loading conversation';
    Role = Role;

    constructor(private fraudService: FraudService) {
        effect(() => {
            const s = this.session();
            if (s) {
                this.isLoading.set(true);
                this.fraudService.getMessages(s.id).subscribe(msgs => {
                    this.messages.set(msgs);
                    this.isLoading.set(false);
                });
            }
        });
    }
}