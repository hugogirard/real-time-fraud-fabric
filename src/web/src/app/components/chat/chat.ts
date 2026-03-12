import { Component, Input, SimpleChanges } from "@angular/core";
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

    @Input() session?: Session;
    messages: Array<Message> = [];
    Role = Role;

    constructor(private fraudService: FraudService) { }

    ngOnInit() {

    }

    ngOnChanges(changes: SimpleChanges) {
        if (changes['session'] && this.session) {
            this.loadMessages(this.session.id);
        }
    }

    loadMessages(sessionId: string) {
        this.fraudService.getMessages(sessionId).subscribe(messages => {
            this.messages = messages;
        });
    }
}