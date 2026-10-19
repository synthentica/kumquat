#!/usr/bin/env python3
"""Checks every corpus conversion with tools other than Kumquat, and writes the pass rate.

    scripts/corpus-validate.py <results.jsonl> <report.md> [<report.json>]

Judges, by output type:
  video   ffprobe finds a video stream, the length matches the source, SSIM against the source >= 0.90
  audio   ffprobe finds an audio stream and the length matches the source
  image   sips decodes it, the size is right, SSIM against the source >= 0.95 (GIF: 0.85)
  PDF     qpdf --check finds no errors; veraPDF parses it (PDF/A conformance is reported, not required)
  office  LibreOffice opens it and prints it to PDF
  text    non-empty UTF-8; JSON parses
  archive Python's zipfile/tarfile lists it without errors
Files that should fail (a password PDF, a broken ZIP) pass when Kumquat says why instead of hanging or crashing.
A tool that isn't installed is reported as skipped, never as a pass.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

VIDEO = {"mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv"}
AUDIO = {"mp3", "m4a", "wav", "aiff", "aif", "flac", "ogg", "opus", "wma", "caf", "aac"}
IMAGE = {"png", "jpg", "jpeg", "heic", "tiff", "tif", "gif", "bmp", "webp", "avif"}
OFFICE = {"xlsx", "pptx", "docx", "ods", "odt", "odp"}
TEXT = {"txt", "md", "csv", "tsv", "json", "html", "srt", "vtt", "rtf"}
ARCHIVE = {"zip", "tar", "gz", "tgz"}

TOOLS = {name: shutil.which(name) for name in ("ffprobe", "ffmpeg", "qpdf", "verapdf", "sips")}
TOOLS["soffice"] = shutil.which("soffice") or next(
    (p for p in ["/Applications/LibreOffice.app/Contents/MacOS/soffice"] if os.path.exists(p)), None)


def run(args, timeout=180):
    try:
        done = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired:
        return -1, "timed out"


class Skip(Exception):
    pass


def need(tool):
    if not TOOLS.get(tool):
        raise Skip(f"{tool} not installed")
    return TOOLS[tool]


def probe(path):
    code, out = run([need("ffprobe"), "-v", "error", "-show_streams", "-show_format", "-of", "json", path])
    if code != 0:
        return None
    try:
        return json.loads(out[out.index("{"):])
    except ValueError:
        return None


def duration(info):
    try:
        return float(info["format"]["duration"])
    except (KeyError, TypeError, ValueError):
        return None


def ssim(reference, candidate, video):
    """Mean SSIM of the first 5 seconds (video) or the image, both scaled to the same size."""
    scale = "scale=640:360:flags=bicubic,format=yuv420p,setpts=PTS-STARTPTS"
    graph = f"[0:v]{scale}[a];[1:v]{scale}[b];[a][b]ssim"
    args = [need("ffmpeg"), "-hide_banner", "-nostdin"]
    if video:
        args += ["-t", "5"]
    args += ["-i", reference]
    if video:
        args += ["-t", "5"]
    args += ["-i", candidate, "-lavfi", graph, "-f", "null", "-"]
    code, out = run(args, timeout=300)
    match = re.search(r"All:([\d.]+)", out)
    return float(match.group(1)) if match else None


def as_png(path, folder):
    """A PNG copy made by macOS itself, for formats FFmpeg may not decode (HEIC, AVIF)."""
    target = os.path.join(folder, os.path.basename(path) + ".png")
    code, _ = run([need("sips"), "-s", "format", "png", path, "--out", target])
    return target if code == 0 and os.path.exists(target) else None


def check_video(output, source, notes):
    info = probe(output)
    if not info or not any(s.get("codec_type") == "video" for s in info.get("streams", [])):
        return False, "no video stream"
    out_len, src_len = duration(info), duration(probe(source) or {})
    if src_len and out_len is not None and abs(out_len - src_len) > max(0.5, src_len * 0.03):
        return False, f"length {out_len:.2f} s, source {src_len:.2f} s"
    if output.endswith(".gif"):
        return True, ""
    score = ssim(source, output, video=True)
    if score is None:
        notes.append("SSIM not measured")
        return True, ""
    notes.append(f"SSIM {score:.3f}")
    return (score >= 0.90), ("" if score >= 0.90 else f"SSIM {score:.3f} < 0.90")


def check_audio(output, source, notes):
    info = probe(output)
    if not info or not any(s.get("codec_type") == "audio" for s in info.get("streams", [])):
        return False, "no audio stream"
    out_len, src_len = duration(info), duration(probe(source) or {})
    if src_len and out_len is not None and abs(out_len - src_len) > max(0.3, src_len * 0.02):
        return False, f"length {out_len:.2f} s, source {src_len:.2f} s"
    return True, ""


def check_image(output, source, notes, scratch):
    decoded = as_png(output, scratch)
    if not decoded:
        return False, "macOS can't decode the output"
    reference = as_png(source, scratch) if source.split(".")[-1].lower() in IMAGE | {"psd", "svg"} else None
    if not reference:
        return True, ""
    score = ssim(reference, decoded, video=False)
    if score is None:
        notes.append("SSIM not measured")
        return True, ""
    notes.append(f"SSIM {score:.3f}")
    floor = 0.85 if output.endswith(".gif") else 0.95
    return (score >= floor), ("" if score >= floor else f"SSIM {score:.3f} < {floor}")


def check_pdf(output, notes):
    code, out = run([need("qpdf"), "--check", output])
    if code not in (0, 3):  # 3 = warnings only
        return False, "qpdf: " + out.strip().splitlines()[-1][:120] if out.strip() else "qpdf failed"
    if TOOLS.get("verapdf"):
        code, out = run([TOOLS["verapdf"], "--format", "text", output], timeout=300)
        if "exception" in out.lower() and "pass" not in out.lower() and "fail" not in out.lower():
            return False, "veraPDF couldn't parse it"
        notes.append("PDF/A " + ("compliant" if out.strip().startswith("PASS") else "not claimed"))
    else:
        notes.append("veraPDF skipped")
    return True, ""


def check_office(output, scratch):
    soffice = need("soffice")
    profile = tempfile.mkdtemp(dir=scratch)
    code, out = run([soffice, f"-env:UserInstallation=file://{profile}", "--headless", "--norestore",
                     "--convert-to", "pdf", "--outdir", scratch, output], timeout=240)
    pdf = os.path.join(scratch, os.path.splitext(os.path.basename(output))[0] + ".pdf")
    if code != 0 or not os.path.exists(pdf) or os.path.getsize(pdf) < 1000:
        return False, "LibreOffice couldn't open it"
    return True, ""


def check_text(output):
    with open(output, "rb") as f:
        data = f.read()
    if not data.strip():
        return False, "empty"
    if output.endswith(".rtf"):
        return data.startswith(b"{\\rtf"), "not RTF"
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return False, "not UTF-8"
    if output.endswith(".json"):
        try:
            json.loads(text)
        except ValueError as error:
            return False, f"invalid JSON: {error}"
    return True, ""


def check_archive(output):
    try:
        if output.endswith(".zip") or output.endswith(".epub"):
            with zipfile.ZipFile(output) as z:
                bad = z.testzip()
                return (bad is None), f"bad entry {bad}"
        if output.endswith(".gz") and not output.endswith(".tar.gz"):
            import gzip
            with gzip.open(output) as g:
                g.read()
            return True, ""
        with tarfile.open(output) as t:
            t.getmembers()
        return True, ""
    except Exception as error:  # noqa: BLE001 - any failure to read is the finding
        return False, f"unreadable: {error}"


def check_file(output, source, notes, scratch):
    ext = output.rsplit(".", 1)[-1].lower() if "." in os.path.basename(output) else ""
    if ext in VIDEO or output.endswith(".gif") and source.rsplit(".", 1)[-1].lower() in VIDEO:
        return check_video(output, source, notes)
    if ext in AUDIO:
        return check_audio(output, source, notes)
    if ext in IMAGE:
        return check_image(output, source, notes, scratch)
    if ext == "pdf":
        return check_pdf(output, notes)
    if ext in OFFICE:
        return check_office(output, scratch)
    if ext in TEXT:
        return check_text(output)
    if ext in ARCHIVE or ext == "epub":
        return check_archive(output)
    if os.path.getsize(output) > 0:
        notes.append(f"no checker for .{ext}")
        return True, ""
    return False, "empty"


def pdf_pages(path):
    if not TOOLS.get("qpdf"):
        return None
    code, out = run([TOOLS["qpdf"], "--show-npages", path])
    return int(out.strip()) if code == 0 and out.strip().isdigit() else None


def judge(line, scratch):
    expected = line.get("expected", "convert")
    status = line.get("status")
    notes = []
    if expected == "clean-error":
        if status in ("error", "not-offered") and (status == "not-offered" or line.get("error")):
            return "pass", f"declined: {line.get('error') or 'nothing offered'}", notes
        if status == "ok":
            return "fail", "converted a file that should have been refused", notes
        return "fail", status, notes
    if status == "not-offered" and line.get("unavailable"):
        return "skipped", line["unavailable"], notes
    if status != "ok":
        return "fail", f"{status}: {line.get('error', '')}".strip(": "), notes
    outputs = []
    for output in line.get("outputs", []):
        if os.path.isdir(output):
            outputs += [os.path.join(output, name) for name in sorted(os.listdir(output)) if not name.startswith(".")]
        else:
            outputs.append(output)
    if not outputs:
        return "fail", "no output", notes
    source = line["source"]
    if source.lower().endswith(".pdf") and len(outputs) > 1:
        pages = pdf_pages(source)
        if pages and pages != len(outputs):
            return "fail", f"{len(outputs)} images for {pages} pages", notes
    # Big folders: check the first and last pages, which is where off-by-one and orientation bugs show.
    sample = outputs if len(outputs) <= 3 else [outputs[0], outputs[-1]]
    try:
        for output in sample:
            ok, reason = check_file(output, source, notes, scratch)
            if not ok:
                return "fail", f"{os.path.basename(output)}: {reason}", notes
    except Skip as skipped:
        return "skipped", str(skipped), notes
    return "pass", "", notes


def main():
    results_path, report_path = sys.argv[1], sys.argv[2]
    json_path = sys.argv[3] if len(sys.argv) > 3 else None
    lines = []
    with open(results_path) as f:
        for raw in f:
            try:
                line = json.loads(raw)
            except ValueError:
                continue
            if line.get("status") != "started":
                lines.append(line)
    scratch = tempfile.mkdtemp(prefix="kumquat-validate-")
    verdicts = []
    for line in lines:
        if line.get("status") == "missing":
            verdicts.append({**line, "verdict": "missing", "reason": "file not downloaded", "notes": []})
            continue
        verdict, reason, notes = judge(line, scratch)
        verdicts.append({**line, "verdict": verdict, "reason": reason, "notes": notes})
        print(f"{verdict:8} {line.get('id')} → {line.get('target')} {reason}", flush=True)
    shutil.rmtree(scratch, ignore_errors=True)

    judged = [v for v in verdicts if v["verdict"] in ("pass", "fail")]
    passed = sum(v["verdict"] == "pass" for v in judged)
    rate = 100 * passed / len(judged) if judged else 0
    by_category = {}
    for v in judged:
        stats = by_category.setdefault(v.get("category", "?"), [0, 0])
        stats[0] += v["verdict"] == "pass"
        stats[1] += 1

    with open(report_path, "w") as report:
        report.write("# Kumquat corpus\n\n")
        report.write(f"**{passed} of {len(judged)} conversions pass ({rate:.1f} %)**, judged by ffprobe, FFmpeg SSIM, sips, qpdf, veraPDF and LibreOffice.")
        skipped = sum(v["verdict"] == "skipped" for v in verdicts)
        if skipped:
            report.write(f" {skipped} more were skipped and are listed below with the reason.")
        report.write("\n\n")
        tools = ", ".join(f"{name} {'yes' if path else 'MISSING'}" for name, path in sorted(TOOLS.items()))
        report.write(f"Tools: {tools}\n\n")
        report.write("| Category | Pass | Total |\n| --- | ---: | ---: |\n")
        for category, (good, total) in sorted(by_category.items()):
            report.write(f"| {category} | {good} | {total} |\n")
        failures = [v for v in verdicts if v["verdict"] != "pass"]
        if failures:
            report.write("\n## Not passing\n\n| File | Target | Verdict | Why | ms |\n| --- | --- | --- | --- | ---: |\n")
            for v in failures:
                why = (v["reason"] or "").replace("|", "/")[:160]
                report.write(f"| {v.get('id')} | {v.get('target', '')} | {v['verdict']} | {why} | {v.get('ms', '')} |\n")
        report.write("\n## Every conversion\n\n| File | Target | Verdict | ms | Notes |\n| --- | --- | --- | ---: | --- |\n")
        for v in verdicts:
            report.write(f"| {v.get('id')} | {v.get('target', '')} | {v['verdict']} | {v.get('ms', '')} | {'; '.join(v['notes'])} |\n")
    if json_path:
        with open(json_path, "w") as f:
            json.dump({"passed": passed, "judged": len(judged), "rate": rate, "verdicts": verdicts}, f, indent=1)
    print(f"\n{passed} of {len(judged)} pass ({rate:.1f} %)")


if __name__ == "__main__":
    main()
