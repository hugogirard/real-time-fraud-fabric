import { Component, Input } from "@angular/core";
import { Session } from "../../model/session";


@Component({
    standalone: true,
    selector: 'session-content',
    template: `
                <div class="sidebar-session-content">
                    <div class="sidebar-session-title">{{ session?.title }}</div>
                    <div class="sidebar-session-meta">
                        <span>{{ session?.created }}</span>
                        @if (session?.resolved) {
                            <span class="badge badge-resolved">resolved</span>
                        } @else {
                            <span class="badge badge-active">active</span>
                        }
                    </div>
                </div>    
    `,
    styles: [`
        .sidebar-session-content {
            flex: 1;
            min-width: 0;
        }
        .sidebar-session-title {
            font-size: var(--font-size-base);
            font-weight: var(--font-weight-semibold);
            color: var(--neutral-gray-130);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .sidebar-session-meta {
            display: flex;
            align-items: center;
            gap: var(--spacing-s);
            margin-top: var(--spacing-xxs);
            font-size: var(--font-size-sm);
            color: var(--neutral-gray-60);
        }
    `]
})
export class SessionComponent {

    @Input() session?: Session;
}