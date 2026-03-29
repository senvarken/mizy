#!/bin/bash
cd ~/iptv
source .env

# Log dizinini oluştur
mkdir -p ~/iptv/logs
LOG_FILE=~/iptv/logs/iptv_debug.log

# Eski process'leri temizle
pkill -f "sync_dropbox" 2>/dev/null
pkill -f "http.server" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null
sleep 2

# Refresh script'lerini çalıştır
./refresh.sh 2>/dev/null || true
./refresh_vavoo.sh 2>/dev/null || true

# HTTP server başlat
python3 -m http.server 8080 &

# Dropbox sync başlat
~/iptv/sync_dropbox.sh &

while true; do
    echo ">>> Tunnel başlatılıyor..."
    cloudflared tunnel --url http://localhost:8080 --protocol http2 2>&1 | while read line; do
        echo "$line"
        TUNNEL_URL=$(echo "$line" | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1)
        
        if [ -n "$TUNNEL_URL" ]; then
            echo "========================================="
            echo "✅ PLAYLIST: $TUNNEL_URL/playlist/playlist.m3u"
            echo "========================================="
            
            mkdir -p ~/iptv/config ~/iptv/playlist
            echo "{\"tunnel\": \"$TUNNEL_URL\"}" > ~/iptv/config/tunnel.json
            
            # Playlist oluştur
            > ~/iptv/playlist/playlist.m3u
            echo "#EXTM3U" > ~/iptv/playlist/playlist.m3u
            echo "" >> ~/iptv/playlist/playlist.m3u
            
            # YouTube kanallarını ekle
            echo ">>> YouTube kanalları ekleniyor..." >> $LOG_FILE
            
            if [ -f "/sdcard/Download/link.json" ]; then
                echo "✅ link.json bulundu" >> $LOG_FILE
                
                # YouTube başlığı
                echo "#EXTINF:-1 group-title=\"📺 YOUTUBE KANALLAR\",=== YOUTUBE KANALLAR ===" >> ~/iptv/playlist/playlist.m3u
                echo "http://0.0.0.0" >> ~/iptv/playlist/playlist.m3u
                echo "" >> ~/iptv/playlist/playlist.m3u
                
                count=0
                # JSON'dan kanalları oku
                while IFS= read -r line; do
                    name=$(echo "$line" | jq -r '.name')
                    url=$(echo "$line" | jq -r '.url')
                    
                    if [ -n "$name" ] && [ "$name" != "null" ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                        # Video ID çıkar
                        video_id=$(echo "$url" | grep -oE '(live/|v=|be/)([a-zA-Z0-9_-]{11})' | grep -oE '[a-zA-Z0-9_-]{11}$' | head -1)
                        if [ -z "$video_id" ]; then
                            video_id=$(echo "$url" | grep -oE '[a-zA-Z0-9_-]{11}' | head -1)
                        fi
                        
                        if [ -n "$video_id" ]; then
                            logo="https://img.youtube.com/vi/${video_id}/maxresdefault.jpg"
                            encoded_name=$(printf "%s" "$name" | jq -sRr @uri)
                            
                            echo "#EXTINF:-1 tvg-logo=\"${logo}\" group-title=\"📺 YOUTUBE KANALLAR\",${name}" >> ~/iptv/playlist/playlist.m3u
                            echo "${TUNNEL_URL}/playlist/${encoded_name}.m3u8" >> ~/iptv/playlist/playlist.m3u
                            
                            count=$((count+1))
                            echo "   ✅ Eklendi: $name" >> $LOG_FILE
                        else
                            echo "   ❌ Video ID yok: $url" >> $LOG_FILE
                        fi
                    fi
                done < <(cat /sdcard/Download/link.json | jq -c '.[]')
                
                echo ">>> Toplam $count YouTube kanalı eklendi" >> $LOG_FILE
                echo "" >> ~/iptv/playlist/playlist.m3u
            else
                echo "❌ link.json bulunamadı!" >> $LOG_FILE
            fi
            
            # Vavoo kanalları
            echo "#EXTINF:-1 group-title=\"🎬 VAVOO KANALLAR\",=== VAVOO KANALLAR ===" >> ~/iptv/playlist/playlist.m3u
            echo "http://0.0.0.0" >> ~/iptv/playlist/playlist.m3u
            echo "" >> ~/iptv/playlist/playlist.m3u
            
            if [ -f "playlist/vavoo_playlist.m3u" ]; then
                sed "s|TUNNEL_URL|${TUNNEL_URL}|g" playlist/vavoo_playlist.m3u >> playlist/playlist.m3u
                echo "✅ Vavoo playlist eklendi" >> $LOG_FILE
            fi
            
            echo "✅ Playlist oluşturuldu - Toplam $(wc -l < ~/iptv/playlist/playlist.m3u) satır" >> $LOG_FILE
        fi
    done

    echo ">>> Tunnel kapandı, yeniden başlatılıyor..." >> $LOG_FILE
    sleep 5
done
