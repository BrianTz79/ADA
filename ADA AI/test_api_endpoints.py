import asyncio
import httpx
import time

async def test_endpoint():
    url = "http://localhost:8000/chat"
    
    queries = [
        "Hola!", # Debería ser fallback (lively)
        "¿Cuáles son los requisitos para el servicio social?", # Debería usar RAG
        "Háblame de física cuántica", # Debería ser fallback (fuera de tema)
        "¿Cuáles son los pasos a seguir de ese trámite?", # Debería usar RAG (con historial)
    ]

    async with httpx.AsyncClient() as client:
        for i, query in enumerate(queries):
            print(f"\n==============================================")
            print(f"🧪 Prueba {i+1}: {query}")
            print(f"==============================================")
            
            t0 = time.time()
            response = await client.post(url, json={"query": query})
            
            if response.status_code == 200:
                print("🤖 ADA:", end=" ")
                # Streaming response reading
                async for chunk in response.aiter_text():
                    print(chunk, end="", flush=True)
                print(f"\n\n[⏱️ Tiempo de respuesta: {time.time() - t0:.2f}s]")
            else:
                print(f"❌ Error HTTP {response.status_code}: {response.text}")
            
            # Un pequeño delay entre pruebas
            await asyncio.sleep(2)

if __name__ == "__main__":
    asyncio.run(test_endpoint())
