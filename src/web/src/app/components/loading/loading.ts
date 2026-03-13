import { Component, input } from "@angular/core";


@Component({
    selector: 'loading',
    standalone: true,
    template: `
    @if (isLoading()) {
        <div id="splash-page">
            <div class="page-splash">
                <div class="page-splash-message">
                    <div style="color:white;font-size:24px">{{title()}}</div>
                    <div>
                        <span class="spinner"></span>
                    </div>
                </div>
            </div>
        </div>
    }
`,
    styleUrl: './loading.css'
})
export class Loading {

    title = input('');
    isLoading = input(false);
}