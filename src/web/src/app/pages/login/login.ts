import { Component, Optional } from "@angular/core";
import { Router } from "@angular/router";
import { MsalService } from "@azure/msal-angular";
import { environment } from "../../environments/environment";


@Component({
    selector: 'login',
    standalone: true,
    templateUrl: './login.html',
    styleUrl: './login.css'
})
export class LoginPage {

    constructor(private router: Router,
        @Optional() private authService: MsalService) { }

    ngOnInit() {
        if (environment.useOauth && this.authService &&
            (this.authService.instance.getActiveAccount() || this.authService.instance.getAllAccounts().length > 0)) {
            this.router.navigate(['/fraud']);
        }
    }

    login() {

        if (!environment.useOauth) {
            this.router.navigate(['/fraud']);
            return;
        }

        // Check if user is already logged in
        if (this.authService.instance.getActiveAccount() || this.authService.instance.getAllAccounts().length > 0) {
            this.router.navigate(['/fraud']);
            return;
        }

        this.authService.loginRedirect();
    }

}