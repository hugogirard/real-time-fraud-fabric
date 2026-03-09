import { Component } from "@angular/core";
import { Router } from "@angular/router";


@Component({
    selector: 'login',
    standalone: true,
    templateUrl: './login.html',
    styleUrl: './login.css'
})
export class LoginPage {

    constructor(private router: Router) { }

    login() {
        // Implement ENTRA ID here
        this.router.navigate(['/fraud'])
    }

}