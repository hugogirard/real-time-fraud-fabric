import { Injectable } from "@angular/core";


@Injectable({
    providedIn: 'root'
})
export class StateService {
    modelIsAnswering: Boolean = false
}