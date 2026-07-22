import { ErrorHandler, Injectable } from "@angular/core";
import { MonitoringService } from "./monitoring.service";

@Injectable({
    providedIn: 'root'
})
export class ErrorHandlerService extends ErrorHandler {
    constructor(private monitoringService: MonitoringService) {
        super();
    }

    override handleError(error: any): void {
        this.monitoringService.logException(error);
    }
}