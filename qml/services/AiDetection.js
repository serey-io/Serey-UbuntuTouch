.pragma library
.import "Http.js" as Http

// Winston AI scan through web's /api/ai/detect-content (key stays server-side).
// onOk({ score, is_ai_generated }); onErr({ status, message, reason })
function detect(url, token, text, language, onOk, onErr) {
    var t = String(text || "").trim();
    if (!t) { onOk({ score: 0, is_ai_generated: false }); return null; }
    return Http.send("POST", url, token, { text: t, language: language || "en" },
        function (data) { onOk(data || {}); },
        function (err) {
            var d = (err && err.data) || {};
            onErr({ status: err ? err.status : 0,
                    message: d.message || d.error || (err && err.message) || "",
                    reason: d.reason || null });
        }, 20000);
}

// Vendor out of credits: file bug report as the Winston bot (route ignores our token)
function reportCreditFailure(url, communityId) {
    Http.send("POST", url, null, {
        description: "[Auto-report] AI content detection (Winston AI) failed for community \""
                     + communityId + "\" while publishing from the Ubuntu Touch app: the vendor "
                     + "account is out of credits. is_ai_generated was forced to false for this post.",
        image_urls: null,
        device_info: { user_agent: "Serey Ubuntu Touch", url: "" }
    }, function () {}, function () {});
}

// HTML -> plain text for scanning
function plainText(html) {
    return String(html || "")
        .replace(/<[^>]*>/g, " ")
        .replace(/&nbsp;/g, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"").replace(/&amp;/g, "&")
        .replace(/\s+/g, " ")
        .trim();
}
