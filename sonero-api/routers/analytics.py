from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, timedelta
from pydantic import BaseModel

from database import get_db
from models import PlaybackEvent, Media

router = APIRouter()

class PlaybackLogRequest(BaseModel):
    media_id: int
    duration_watched: float
    completed: bool

@router.post(
    "/analytics/log",
    summary="Log playback event",
    description="Records the duration a user watched or listened to a specific media file."
)
async def log_playback(request: PlaybackLogRequest, db: Session = Depends(get_db)):
    media = db.query(Media).filter(Media.id == request.media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")
        
    event = PlaybackEvent(
        media_id=request.media_id,
        duration_watched=request.duration_watched,
        completed=request.completed,
        start_time=datetime.utcnow()
    )
    db.add(event)
    db.commit()
    
    return {"message": "Playback logged successfully", "event_id": event.id}

@router.get(
    "/analytics/history",
    summary="Get playback history",
)
async def get_history(limit: int = 50, db: Session = Depends(get_db)):
    events = db.query(PlaybackEvent).order_by(PlaybackEvent.start_time.desc()).limit(limit).all()
    return [{
        "id": e.id,
        "media_id": e.media_id,
        "title": e.media.title if e.media else "Unknown",
        "duration_watched": e.duration_watched,
        "completed": e.completed,
        "start_time": e.start_time
    } for e in events]


@router.get(
    "/analytics/stats",
    summary="Get download and library statistics",
)
async def get_stats(db: Session = Depends(get_db)):
    """Returns real statistics from the downloaded media library."""
    # Total counts
    total_songs = db.query(func.count(Media.id)).filter(Media.type == "music").scalar() or 0
    total_videos = db.query(func.count(Media.id)).filter(Media.type == "video").scalar() or 0
    total_media = db.query(func.count(Media.id)).scalar() or 0

    # Top artists (by number of downloads)
    top_artists_query = (
        db.query(Media.artist, func.count(Media.id).label("count"))
        .filter(Media.artist.isnot(None), Media.artist != "")
        .group_by(Media.artist)
        .order_by(func.count(Media.id).desc())
        .limit(10)
        .all()
    )
    top_artists = [{"artist": a, "count": c} for a, c in top_artists_query]

    # Top genres
    top_genres_query = (
        db.query(Media.genre, func.count(Media.id).label("count"))
        .filter(Media.genre.isnot(None), Media.genre != "")
        .group_by(Media.genre)
        .order_by(func.count(Media.id).desc())
        .limit(10)
        .all()
    )
    top_genres = [{"genre": g, "count": c} for g, c in top_genres_query]

    # Recent downloads (last 20)
    recent = (
        db.query(Media)
        .order_by(Media.added_at.desc())
        .limit(20)
        .all()
    )
    recent_downloads = [{
        "id": m.id,
        "title": m.title,
        "artist": m.artist or "Desconocido",
        "type": m.type,
        "format": m.format,
        "cover_url": m.cover_url or "",
        "added_at": m.added_at.isoformat() if m.added_at else None,
    } for m in recent]

    # Downloads by format
    format_stats = (
        db.query(Media.format, func.count(Media.id).label("count"))
        .group_by(Media.format)
        .all()
    )
    formats = {f: c for f, c in format_stats}

    # Downloads this week
    week_ago = datetime.utcnow() - timedelta(days=7)
    this_week = db.query(func.count(Media.id)).filter(Media.added_at >= week_ago).scalar() or 0

    # Downloads today
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    today_count = db.query(func.count(Media.id)).filter(Media.added_at >= today_start).scalar() or 0

    return {
        "total_songs": total_songs,
        "total_videos": total_videos,
        "total_media": total_media,
        "this_week": this_week,
        "today": today_count,
        "top_artists": top_artists,
        "top_genres": top_genres,
        "recent_downloads": recent_downloads,
        "formats": formats,
    }


@router.post(
    "/analytics/sync",
    summary="Sync downloads folder with DB and clean up junk files",
)
async def sync_downloads(db: Session = Depends(get_db)):
    """
    Scans the downloads folder for real audio/video files,
    registers any missing ones in the DB, and cleans up
    leftover thumbnails and failed downloads.
    """
    from config import settings
    from pathlib import Path
    import os

    music_dir = settings.MUSIC_DIR
    video_dir = settings.VIDEO_DIR

    audio_exts = {".mp3", ".m4a", ".opus", ".ogg", ".wav", ".aac", ".flac", ".wma", ".webm"}
    video_exts = {".mp4", ".mkv", ".webm", ".avi", ".mov"}
    junk_exts = {".webp", ".jpg", ".jpeg", ".png", ".part", ".ytdl", ".temp"}

    added = 0
    cleaned = 0
    errors = []

    for folder, media_type, valid_exts in [
        (music_dir, "music", audio_exts),
        (video_dir, "video", video_exts),
    ]:
        if not folder.exists():
            continue

        for f in folder.iterdir():
            if f.is_dir():
                continue

            ext = f.suffix.lower()

            # Clean up junk files
            if ext in junk_exts:
                try:
                    f.unlink()
                    cleaned += 1
                except Exception as e:
                    errors.append(f"Could not delete {f.name}: {e}")
                continue

            # Skip non-media files
            if ext not in valid_exts:
                # Check if it's a file with no extension but too small (failed download)
                if ext == "" and f.stat().st_size < 10000:
                    try:
                        f.unlink()
                        cleaned += 1
                    except Exception:
                        pass
                continue

            # Skip tiny files (< 10KB = probably failed)
            if f.stat().st_size < 10000:
                try:
                    f.unlink()
                    cleaned += 1
                except Exception:
                    pass
                continue

            # Check if already in DB
            existing = db.query(Media).filter(Media.filename == f.name).first()
            if existing:
                continue

            # Parse artist - title from filename
            stem = f.stem.lstrip("- ").strip()
            if " - " in stem:
                parts = stem.split(" - ", 1)
                artist = parts[0].strip()
                title = parts[1].strip()
            else:
                artist = ""
                title = stem

            media = Media(
                type=media_type,
                title=title,
                artist=artist,
                album="",
                genre="",
                year="",
                filename=f.name,
                format=ext.lstrip("."),
                cover_url="",
                shazam_url="",
                added_at=datetime.fromtimestamp(os.path.getmtime(f)),
            )
            db.add(media)
            added += 1

    db.commit()

    return {
        "added": added,
        "cleaned": cleaned,
        "errors": errors,
        "message": f"Sincronización completa: {added} archivos añadidos, {cleaned} archivos basura eliminados.",
    }
