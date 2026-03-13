import { Component, input, signal, effect, computed } from "@angular/core";
import { DatePipe } from "@angular/common";
import { FraudService } from "../../services/fraud.service";
import { Message, Role } from "../../model/message";
import { Session } from "../../model/session";



@Component({
    selector: 'chat-pane',
    standalone: true,
    styleUrl: './chat.css',
    templateUrl: './chat.html',
    imports: [DatePipe]
})
export class Chat {

    session = input<Session>();
    messages = signal<Message[]>([]);
    Role = Role;

    constructor(private fraudService: FraudService) {
        effect(() => {
            const s = this.session();
            if (s) {
                this.fraudService.getMessages(s.id).subscribe(msgs => {
                    this.messages.set(msgs);
                });
            }
        });
    }
}