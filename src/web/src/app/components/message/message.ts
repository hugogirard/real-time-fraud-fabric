import { Component, Input } from "@angular/core";
import { Message } from "../../model/message";


@Component({
    standalone: true,
    selector: 'message',
    styleUrl: './message.css',
    templateUrl: './message.html'
})
export class MessageComponent {

    @Input()
    message: Message | null = null;
}