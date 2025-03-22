declare module 'ollama' {
  export type Fetch = typeof fetch;
  export interface Config {
    host?: string;
    fetch?: Fetch;
    proxy?: boolean;
    headers?: HeadersInit;
  }

  export interface EmbeddingsRequest {
    model: string;
    prompt: string;
    keep_alive?: string | number;
    options?: Record<string, any>;
  }

  export interface EmbeddingsResponse {
    embedding: number[];
  }
  export class Ollama {
    constructor(config?: Config);
      embeddings(request: EmbeddingsRequest): Promise<EmbeddingsResponse>;
  }

  const ollama: Ollama;

  export default ollama;
}
