import { Routes } from '@angular/router';
import { LoginPage } from './pages/login/login';
import { FraudPage } from './pages/fraud/fraud';

export const routes: Routes = [
    {
        path: '',
        component: LoginPage,
    },
    {
        path: 'fraud',
        component: FraudPage,
    },
];
