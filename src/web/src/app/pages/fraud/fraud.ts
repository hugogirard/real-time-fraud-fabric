import { Component } from "@angular/core";
import { SideBar } from "../../components/sidebar/sidebar";
import { Chat } from "../../components/chat/chat";

@Component({
    selector: 'fraud',
    standalone: true,
    templateUrl: './fraud.html',
    styleUrl: './fraud.css',
    imports: [SideBar, Chat]
})
export class FraudPage {

}