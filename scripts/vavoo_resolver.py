import asyncio
import logging
import time
import socket
import hashlib
import aiohttp
from aiohttp import ClientSession, ClientTimeout, TCPConnector
from typing import Optional, Dict, Any
from urllib.parse import quote_plus
import random
import sys
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

_LOKKE_PING_URL = "https://www.lokke.app/api/app/ping"
_LOKKE_TOKEN = "ldCvE092e7gER0rVIajfsXIvRhwlrAzP6_1oEJ4q6HH89QHt24v6NNL_jQJO219hiLOXF2hqEfsUuEWitEIGN4EaHHEHb7Cd7gojc5SQYRFzU3XWo_kMeryAUbcwWnQrnf0-"
_RESOLVE_URL = "https://vavoo.to/mediahubmx-resolve.json"
_TS_PING2_URL = "https://www.vavoo.tv/api/box/ping2"
_TS_VEC = "9frjpxPjxSNilxJPCJ0XGYs6scej3dW/h/VWlnKUiLSG8IP7mfyDU7NirOlld+VtCKGj03XjetfliDMhIev7wcARo+YTU8KPFuVQP9E2DVXzY2BFo1NhE6qEmPfNDnm74eyl/7iFJ0EETm6XbYyz8IKBkAqPN/Spp3PZ2ulKg3QBSDxcVN4R5zRn7OsgLJ2CNTuWkd/h451lDCp+TtTuvnAEhcQckdsydFhTZCK5IiWrrTIC/d4qDXEd+GtOP4hPdoIuCaNzYfX3lLCwFENC6RZoTBYLrcKVVgbqyQZ7DnLqfLqvf3z0FVUWx9H21liGFpByzdnoxyFkue3NzrFtkRL37xkx9ITucepSYKzUVEfyBh+/3mtzKY26VIRkJFkpf8KVcCRNrTRQn47Wuq4gC7sSwT7eHCAydKSACcUMMdpPSvbvfOmIqeBNA83osX8FPFYUMZsjvYNEE3arbFiGsQlggBKgg1V3oN+5ni3Vjc5InHg/xv476LHDFnNdAJx448ph3DoAiJjr2g4ZTNynfSxdzA68qSuJY8UjyzgDjG0RIMv2h7DlQNjkAXv4k1BrPpfOiOqH67yIarNmkPIwrIV+W9TTV/yRyE1LEgOr4DK8uW2AUtHOPA2gn6P5sgFyi68w55MZBPepddfYTQ+E1N6R/hWnMYPt/i0xSUeMPekX47iucfpFBEv9Uh9zdGiEB+0P3LVMP+q+pbBU4o1NkKyY1V8wH1Wilr0a+q87kEnQ1LWYMMBhaP9yFseGSbYwdeLsX9uR1uPaN+u4woO2g8sw9Y5ze5XMgOVpFCZaut02I5k0U4WPyN5adQjG8sAzxsI3KsV04DEVymj224iqg2Lzz53Xz9yEy+7/85ILQpJ6llCyqpHLFyHq/kJxYPhDUF755WaHJEaFRPxUqbparNX+mCE9Xzy7Q/KTgAPiRS41FHXXv+7XSPp4cy9jli0BVnYf13Xsp28OGs/D8Nl3NgEn3/eUcMN80JRdsOrV62fnBVMBNf36+LbISdvsFAFr0xyuPGmlIETcFyxJkrGZnhHAxwzsvZ+Uwf8lffBfZFPRrNv+tgeeLpatVcHLHZGeTgWWml6tIHwWUqv2TVJeMkAEL5PPS4Gtbscau5HM+FEjtGS+KClfX1CNKvgYJl7mLDEf5ZYQv5kHaoQ6RcPaR6vUNn02zpq5/X3EPIgUKF0r/0ctmoT84B2J1BKfCbctdFY9br7JSJ6DvUxyde68jB+Il6qNcQwTFj4cNErk4x719Y42NoAnnQYC2/qfL/gAhJl8TKMvBt3Bno+va8ve8E0z8yEuMLUqe8OXLce6nCa+L5LYK1aBdb60BYbMeWk1qmG6Nk9OnYLhzDyrd9iHDd7X95OM6X5wiMVZRn5ebw4askTTc50xmrg4eic2U1w1JpSEjdH/u/hXrWKSMWAxaj34uQnMuWxPZEXoVxzGyuUbroXRfkhzpqmqqqOcypjsWPdq5BOUGL/Riwjm6yMI0x9kbO8+VoQ6RYfjAbxNriZ1cQ+AW1fqEgnRWXmjt4Z1M0ygUBi8w71bDML1YG6UHeC2cJ2CCCxSrfycKQhpSdI1QIuwd2eyIpd4LgwrMiY3xNWreAF+qobNxvE7ypKTISNrz0iYIhU0aKNlcGwYd0FXIRfKVBzSBe4MRK2pGLDNO6ytoHxvJweZ8h1XG8RWc4aB5gTnB7Tjiqym4b64lRdj1DPHJnzD4aqRixpXhzYzWVDN2kONCR5i2quYbnVFN4sSfLiKeOwKX4JdmzpYixNZXjLkG14seS6KR0Wl8Itp5IMIWFpnNokjRH76RYRZAcx0jP0V5/GfNNTi5QsEU98en0SiXHQGXnROiHpRUDXTl8FmJORjwXc0AjrEMuQ2FDJDmAIlKUSLhjbIiKw3iaqp5TVyXuz0ZMYBhnqhcwqULqtFSuIKpaW8FgF8QJfP2frADf4kKZG1bQ99MrRrb2A="


async def get_auth_signature(session) -> Optional[str]:
    unique_id = hashlib.md5(str(time.time()).encode()).hexdigest()[:16]
    now_ms = int(time.time() * 1000)
    body = {
        "token": _LOKKE_TOKEN,
        "reason": "app-blur",
        "locale": "de",
        "theme": "dark",
        "metadata": {
            "device": {"type": "Handset", "brand": "google", "model": "Nexus", "name": "21081111RG", "uniqueId": unique_id},
            "os": {"name": "android", "version": "7.1.2", "abis": ["arm64-v8a"], "host": "android"},
            "app": {"platform": "android", "version": "1.1.0", "buildId": "97215000", "engine": "hbc85",
                    "signatures": ["6e8a975e3cbf07d5de823a760d4c2547f86c1403105020adee5de67ac510999e"],
                    "installer": "com.android.vending"},
            "version": {"package": "app.lokke.main", "binary": "1.1.0", "js": "1.1.0"},
            "platform": {"isAndroid": True, "isIOS": False, "isTV": False, "isWeb": False,
                         "isMobile": True, "isWebTV": False, "isElectron": False}
        },
        "appFocusTime": 0, "playerActive": False, "playDuration": 0,
        "devMode": True, "hasAddon": True, "castConnected": False,
        "package": "app.lokke.main", "version": "1.1.0", "process": "app",
        "firstAppStart": now_ms - 86400000, "lastAppStart": now_ms,
        "ipLocation": None, "adblockEnabled": False,
        "proxy": {"supported": ["ss", "openvpn"], "engine": "openvpn", "ssVersion": 1,
                  "enabled": False, "autoServer": True, "id": "fi-hel"},
        "iap": {"supported": True}
    }
    headers = {
        "user-agent": "okhttp/4.11.0",
        "accept": "application/json",
        "content-type": "application/json; charset=utf-8",
        "accept-encoding": "gzip",
    }
    try:
        async with session.post(_LOKKE_PING_URL, json=body, headers=headers, timeout=ClientTimeout(total=15)) as resp:
            if resp.status == 200:
                data = await resp.json()
                return data.get("addonSig")
    except Exception as e:
        logger.warning(f"Auth sig error: {e}")
    return None


async def get_ts_signature(session) -> Optional[str]:
    try:
        async with session.post(
            _TS_PING2_URL,
            data={"vec": _TS_VEC},
            headers={"content-type": "application/x-www-form-urlencoded"},
            timeout=ClientTimeout(total=15)
        ) as resp:
            if resp.status == 200:
                data = await resp.json()
                return data.get("response", {}).get("signed")
    except Exception as e:
        logger.warning(f"TS sig error: {e}")
    return None


async def resolve_url(vavoo_url: str) -> Optional[str]:
    connector = TCPConnector(family=socket.AF_INET)
    async with ClientSession(connector=connector) as session:

        # Yöntem 1: lokke.app auth + mediahubmx
        sig = await get_auth_signature(session)
        if sig:
            headers = {
                "user-agent": "MediaHubMX/2",
                "accept": "application/json",
                "content-type": "application/json; charset=utf-8",
                "accept-encoding": "gzip",
                "mediahubmx-signature": sig,
            }
            body = {"language": "de", "region": "AT", "url": vavoo_url, "clientVersion": "3.0.2"}
            try:
                async with session.post(_RESOLVE_URL, json=body, headers=headers, timeout=ClientTimeout(total=15)) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if isinstance(data, list) and data and data[0].get("url"):
                            return str(data[0]["url"])
                        if isinstance(data, dict) and data.get("url"):
                            return str(data["url"])
            except Exception as e:
                logger.warning(f"Resolve error: {e}")

        # Yöntem 2: TS fallback
        ts_sig = await get_ts_signature(session)
        if ts_sig:
            import re
            m = re.search(r'/play/([^/?#]+)', vavoo_url)
            if m:
                token = m.group(1)
                return f"https://www2.vavoo.to/live2/{token}.ts?n=1&b=5&vavoo_auth={quote_plus(ts_sig)}"

    return None


async def main():
    if len(sys.argv) < 2:
        print("Kullanım: python vavoo_resolver.py VAVOO_URL")
        sys.exit(1)

    url = sys.argv[1]
    print(f"Resolving: {url}")
    result = await resolve_url(url)
    if result:
        print(f"RESOLVED: {result}")
    else:
        print("HATA: URL çözülemedi")


if __name__ == "__main__":
    asyncio.run(main())
