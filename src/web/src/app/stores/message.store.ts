import { Injectable } from "@angular/core";
import { patchState, signalState, signalStore } from "@ngrx/signals";
import { FraudService } from "../services/fraud.service";
import { HttpEventType } from "@angular/common/http";


@Injectable({
    providedIn: 'root'
})
export class MessageStore {

    constructor(private fraudService: FraudService) { }

    private state = signalState({
        messages: [] as { role: string; content: string }[],
        streamingContent: '',
        isStreaming: false,
        lastSessionInfo: null as any
    });

    readonly messages = this.state.messages;
    readonly streamingContent = this.state.streamingContent;
    readonly isStreaming = this.state.isStreaming;

    addWelcomeMessage(content: string) {
        patchState(this.state, (state) => ({
            messages: [...state.messages, { role: 'assistant', content }]
        }));
    }

    sendMessage(prompt: string) {
        patchState(this.state, (state) => ({
            messages: [...state.messages, { role: 'user', content: prompt }],
            streamingContent: '',
            isStreaming: true
        }));

        this.fraudService.askQuestion(prompt).subscribe({
            next: (event) => {
                if (event.type === HttpEventType.DownloadProgress) {
                    const rawData = (event as any).partialText;
                    this.parseStream(rawData);
                }
                if (event.type === HttpEventType.Response) {
                    this.finalize();
                }
            },
            error: () => patchState(this.state, { isStreaming: false })
        });
    }

    private parseStream(raw: string) {
        try {
            // Backend sends concatenated JSON objects: {"type":"content","text":"I"}{"type":"content","text":" can"}
            // Split them by looking for }{ boundaries
            const jsonStrings = raw
                .split(/(?<=\})\s*(?=\{)/)
                .filter(s => s.trim());

            let fulltext = '';
            let parsed = false;

            for (const jsonStr of jsonStrings) {
                try {
                    const obj = JSON.parse(jsonStr);
                    parsed = true;

                    if (obj.type === 'content') {
                        fulltext += obj.text;
                    } else if (obj.type === 'session_info') {
                        patchState(this.state, { lastSessionInfo: obj });
                    }
                } catch {
                    // Incomplete chunk, skip
                }
            }

            if (parsed) {
                patchState(this.state, { streamingContent: fulltext });
            }
        } catch {
            // Ignore parse errors from partial chunks
        }
    }

    private finalize() {
        patchState(this.state, (state) => ({
            messages: [...state.messages, { role: 'assistant', content: state.streamingContent }],
            streamingContent: '',
            isStreaming: false
        }));
    }

}