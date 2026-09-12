/**
 * @description Booking-focused Calendly API v2 service. Self-contained: shares no
 *              code with CalendlyService (separate class by design). Auth is handled
 *              entirely by the Named Credential "Calendly_API" — Apex never sees tokens.
 *
 *              Both public methods resolve the event type internally (first ACTIVE
 *              event type of the current user), so callers only supply booking details.
 */
public with sharing class CalendlyBookingService {

    // ─── Constants ────────────────────────────────────────────────────────────
    private static final String  BASE        = 'callout:Calendly_API';
    private static final Integer PAGE_SIZE   = 100;
    private static final Integer MAX_RETRIES = 2;

    // ─── Public wrapper types ─────────────────────────────────────────────────

    /** One open slot from GET /event_type_available_times. */
    public class AvailableTime {
        public String  startTime;          // ISO-8601 UTC, e.g. '2026-09-07T04:00:00Z'
        public Integer inviteesRemaining;
    }

    /** Result of POST /invitees — key fields from the created invitee resource. */
    public class CreatedInvitee {
        public String uri;
        public String email;
        public String name;
        public String firstName;
        public String lastName;
        public String status;              // active
        public String eventUri;            // the scheduled event URI
    }

    // ─── Custom exception ─────────────────────────────────────────────────────

    /**
     * @description Thrown on non-2xx responses, and on internal resolution failures
     *              (e.g. no active event type). Check statusCode to distinguish
     *              plan-gate errors (402/403) from other failures; statusCode is
     *              null for internal (non-HTTP) failures.
     */
    public class CalendlyException extends Exception {
        public Integer statusCode;
        public String  responseBody;

        /** @param code HTTP status. @param body Raw response text. */
        public CalendlyException(Integer code, String body) {
            this('Calendly API error ' + code + ': ' + body);
            this.statusCode   = code;
            this.responseBody = body;
        }
    }

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * @description Returns open booking slots for the current user's first active
     *              event type. Window: now → now+7 days (Calendly max range).
     * @return List of available slots, each with startTime and inviteesRemaining.
     */
    public static List<AvailableTime> getAvailableTimes() {
        String eventTypeUri = resolveEventTypeUri();

        DateTime startDt = DateTime.now().addMinutes(5);
        DateTime endDt   = startDt.addDays(7);
        Map<String, String> params = new Map<String, String>{
            'event_type' => eventTypeUri,
            'start_time' => startDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'end_time'   => endDt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        };

        HttpResponse res = execute('GET', '/event_type_available_times' + buildQueryString(params), null);
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> items = (List<Object>) root.get('collection');

        List<AvailableTime> results = new List<AvailableTime>();
        if (items != null) {
            for (Object item : items) {
                Map<String, Object> m = (Map<String, Object>) item;
                AvailableTime at = new AvailableTime();
                at.startTime         = (String)  m.get('start_time');
                at.inviteesRemaining = (Integer) m.get('invitees_remaining');
                results.add(at);
            }
        }
        return results;
    }

    /**
     * @description Directly books a Calendly event (Scheduling API) against the
     *              current user's first active event type.
     *              POST /invitees — requires the Scheduling API on the account plan.
     * @param startTimeIso  ISO-8601 UTC start time, e.g. '2026-09-15T10:00:00.000000Z'.
     * @param inviteeEmail  Invitee e-mail address.
     * @param inviteeName   Invitee display name (optional, pass null to omit).
     * @param timezone      IANA timezone, e.g. 'Asia/Kolkata'.
     * @param locationKind  Calendly location kind, e.g. 'google_conference',
     *                      'zoom_conference', 'gotomeeting'. Passed straight through
     *                      by the (future) invocable caller.
     * @return CreatedInvitee with uri, email, name and status populated.
     */
    public static CreatedInvitee bookMeeting(
            String startTimeIso, String inviteeEmail,
            String inviteeName, String timezone, String locationKind) {

        String eventTypeUri = resolveEventTypeUri();

        Map<String, Object> invitee = new Map<String, Object>{
            'email'    => inviteeEmail,
            'timezone' => timezone
        };
        if (String.isNotBlank(inviteeName)) {
            invitee.put('name', inviteeName);
        }

        Map<String, Object> body = new Map<String, Object>{
            'event_type' => eventTypeUri,
            'start_time' => startTimeIso,
            'invitee'    => invitee,
            // Scheduling API does NOT inherit the event type's default location —
            // it must be sent explicitly or the booking falls back to
            // {"type":"custom","location":null} with no meeting link.
            'location'   => new Map<String, Object>{ 'kind' => locationKind }
        };

        HttpResponse res = execute('POST', '/invitees', JSON.serialize(body));
        Map<String, Object> root     = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> resource = (Map<String, Object>) root.get('resource');

        CreatedInvitee ci = new CreatedInvitee();
        ci.uri       = (String) resource.get('uri');
        ci.email     = (String) resource.get('email');
        ci.name      = (String) resource.get('name');
        ci.firstName = (String) resource.get('first_name');
        ci.lastName  = (String) resource.get('last_name');
        ci.status    = (String) resource.get('status');
        ci.eventUri  = (String) resource.get('event');
        return ci;
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /**
     * @description Resolves the event type URI to operate on: the FIRST ACTIVE
     *              event type of the current user. Shared by both public methods.
     * @return Full event type URI.
     * @throws CalendlyException if the user has no active event types.
     */
    private static String resolveEventTypeUri() {
        // 1) who am I
        HttpResponse meRes = execute('GET', '/users/me', null);
        Map<String, Object> meRoot = (Map<String, Object>) JSON.deserializeUntyped(meRes.getBody());
        Map<String, Object> meResource = (Map<String, Object>) meRoot.get('resource');
        String userUri = (String) meResource.get('uri');

        // 2) my event types (paginated)
        Map<String, String> params = new Map<String, String>{
            'user'  => userUri,
            'count' => String.valueOf(PAGE_SIZE)
        };
        List<Object> items = getPaginated('/event_types', params);

        // 3) first ACTIVE one
        for (Object item : items) {
            Map<String, Object> m = (Map<String, Object>) item;
            Boolean active = (Boolean) m.get('active');
            if (active == true) {
                return (String) m.get('uri');
            }
        }
        throw new CalendlyException(null, 'No active event type found for the current user.');
    }

    /**
     * @description Executes a GET across all pages, collecting every item from the
     *              'collection' array. Stops when next_page_token is null.
     */
    private static List<Object> getPaginated(String path, Map<String, String> baseParams) {
        List<Object> all = new List<Object>();
        String nextToken = null;
        do {
            Map<String, String> params = new Map<String, String>(baseParams);
            if (nextToken != null) {
                params.put('page_token', nextToken);
            }
            HttpResponse res = execute('GET', path + buildQueryString(params), null);
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            List<Object> collection = (List<Object>) root.get('collection');
            if (collection != null) {
                all.addAll(collection);
            }

            nextToken = null;
            Map<String, Object> pagination = (Map<String, Object>) root.get('pagination');
            if (pagination != null) {
                nextToken = (String) pagination.get('next_page_token');
            }
        } while (nextToken != null);
        return all;
    }

    /**
     * @description Core callout executor with 429 retry logic (up to MAX_RETRIES).
     *              Throws CalendlyException on non-2xx (including plan-gate 402/403).
     */
    private static HttpResponse execute(String method, String path, String jsonBody) {
        HttpResponse lastRes = null;
        for (Integer attempts = 0; attempts <= MAX_RETRIES; attempts++) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE + path);
            req.setMethod(method);
            req.setHeader('Content-Type', 'application/json');
            if (jsonBody != null) {
                req.setBody(jsonBody);
            }

            lastRes = new Http().send(req);
            Integer code = lastRes.getStatusCode();

            if (code == 429 && attempts < MAX_RETRIES) {
                // Apex has no Thread.sleep; Retry-After is logged only.
                // Move to Queueable if real back-off is required.
                System.debug('Calendly 429 — Retry-After: ' + retryAfterSeconds(lastRes)
                        + 's (attempt ' + (attempts + 1) + ')');
                continue;
            }
            if (code >= 200 && code < 300) {
                return lastRes;
            }
            throw new CalendlyException(code, lastRes.getBody());
        }
        throw new CalendlyException(lastRes.getStatusCode(), lastRes.getBody());
    }

    /** Parses Retry-After header (integer seconds); defaults to 1 if absent/invalid. */
    private static Integer retryAfterSeconds(HttpResponse res) {
        String header = res.getHeader('Retry-After');
        if (String.isBlank(header)) { return 1; }
        try { return Integer.valueOf(header); } catch (Exception e) { return 1; }
    }

    /** Builds a URL query string from a map, e.g. '?a=1&b=2'. */
    private static String buildQueryString(Map<String, String> params) {
        if (params == null || params.isEmpty()) { return ''; }
        List<String> parts = new List<String>();
        for (String k : params.keySet()) {
            parts.add(EncodingUtil.urlEncode(k, 'UTF-8') + '='
                    + EncodingUtil.urlEncode(params.get(k), 'UTF-8'));
        }
        return '?' + String.join(parts, '&');
    }
}