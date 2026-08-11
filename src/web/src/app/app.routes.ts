import { Routes } from '@angular/router';
import { LoginPage } from './pages/login/login';
import { FraudPage } from './pages/fraud/fraud';
import { MsalGuard } from '@azure/msal-angular';

export const routes: Routes = [
    {
        path: '',
        component: LoginPage,
    },
    {
        path: 'fraud',
        component: FraudPage,
        canActivate: [MsalGuard]
    },
];
