import { Injectable, signal } from "@angular/core";

@Injectable({
    providedIn: 'root'
})
export class StateService {

    constructor() { }
    modelIsAnswering = signal(false);

    setItem<T>(key: string, value: T): void {
        const stringValue = JSON.stringify(value);
        sessionStorage.setItem(key, stringValue);
    }

    getSessionItem<T>(key: string): T | null {
        const data = sessionStorage.getItem(key);
        if (!data) return null;

        try {
            return JSON.parse(data) as T;
        } catch (e) {
            console.error("Error parsing sessionStorage data", e);
            return null;
        }
    }
}