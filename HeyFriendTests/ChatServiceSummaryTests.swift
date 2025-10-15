//
//  ChatServiceSummaryTests.swift
//  HeyFriendTests
//
//  Created by Denis Tatar 2 on 10/14/25.
//

import Foundation
import XCTest
@testable import HeyFriend

// MARK: - Mock URLProtocol to stub OpenAI responses
final class MockURLProtocol: URLProtocol {
    static var responseQueue: [(status: Int, json: String)] = []
    static var lastRequestBodyJSON: [String: Any]? = nil

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept OpenAI chat completions
        request.url?.absoluteString.contains("/v1/chat/completions") == true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // capture body (optional)
        if let body = request.httpBody,
           let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            MockURLProtocol.lastRequestBodyJSON = obj
        }

        // Dequeue next canned response (use labeled tuple type so .status/.json work)
        let item: (status: Int, json: String) = MockURLProtocol.responseQueue.isEmpty
        ? (status: 200, json: #"{"choices":[{"message":{"content":"{\"bullets\":[\"ok\"],\"gratitude_mentions\":0,\"local_tone\":\"Calm\",\"language\":{\"repeated_words\":[],\"thinking_style\":\"\",\"emotional_indicators\":\"\"}}"}}]}"#)
        : MockURLProtocol.responseQueue.removeFirst()

        let data = Data(item.json.utf8)
        let url = request.url!
        let resp = HTTPURLResponse(
            url: url, statusCode: item.status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        print("🔒 Mock hit:", request.url?.absoluteString ?? "(nil)")

        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    static func enqueue(status: Int = 200, json: String) {
        responseQueue.append((status: status, json: json))
    }
}

// MARK: - Tests
final class ChatServiceSummaryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setenv("SOME_SOME", "TEST_KEY", 1)

        // 1) Global intercept for any URLSession (including URLSession.shared)
        URLProtocol.registerClass(MockURLProtocol.self)

        // 2) Also force ChatService to use a session that uses our mock
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        ChatService.shared.session = URLSession(configuration: config)

        MockURLProtocol.responseQueue.removeAll()
        MockURLProtocol.lastRequestBodyJSON = nil
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        super.tearDown()
    }

    func testGenerateSummary_FullCoverageAndGratitudeGuard() {
        // -------- Transcript with TWO gratitude utterances --------
//        let transcript = """
//        You: Quick update — I’m grateful for my wife helping with chores.
//        HeyFriend: That’s lovely. Anything else you feel thankful for?
//        You: Yeah, I’m really grateful for the sunny weather today.
//        HeyFriend: Great to hear. What’s next on your mind?
//        """
        
        // ===== Transcript under test (your 30-min convo) =====
        let transcript = """
        You: Hey how's it going it's been a while since we last spoke
        HeyFriend: Hi! It's nice to hear from you. I'm doing well, thanks for asking. How have you been? Anything new or exciting happening in your life?

        You: Honestly ton of new things I've actually happened I've been traveling I took a little bit of a pause from jobhunting even though I'm still anxious about it but overall I'm coming back and getting back into the rhythm of things and a lot has happened
        HeyFriend: It sounds like you've been through a busy and exciting time! Traveling can be such a refreshing break. It's also understandable to feel anxious about job hunting. How are you feeling about getting back into the rhythm of things?

        You: Honestly it feels great when I first landed back though I was exhausted and just honestly really really really in my head like negatively and I could tell whenever I'm tired I get really negative about my thoughts
        You: Honestly it feels great when I first landed back though I was exhausted and just honestly
        HeyFriend: It's completely normal to feel off when you're tired, and it's great that you recognize how it affects your thoughts. Rest can make a big difference. Have you found any strategies that help manage those negative thoughts when they arise?
        HeyFriend: It makes sense that exhaustion would impact your thoughts and mood. It's good that you're aware of how tiredness affects you. Have you found any strategies that help you manage those negative thoughts when you're feeling this way?

        You: Yeah honestly the big one is just getting back into sleep and honestly I didn't really sleep too much but I'm actually grateful though for the opportunity to sleep in again and and just rest up
        HeyFriend: Getting enough sleep can make such a difference in how we feel. It’s great that you’re prioritizing rest and allowing yourself to recharge. Do you have any other routines or activities that help you relax and reset?

        You: Well I recently just bought Battlefield sick so I don't know if that's really helping me relax but it's taking my mind off a lot of things and honestly I'm having
        You: Well I recently just bought Battlefield sick so I don't know if that's really helping me relax but it's taking my mind off a lot of things and honestly I'm having a to
        HeyFriend: Playing games like Battlefield can be a fun way to unwind and take your mind off things. It sounds like it's providing a good distraction for you. Are you finding it helps balance out the stress from other areas of your life?
        HeyFriend: It sounds like playing Battlefield is providing a good distraction and some fun, which can be really helpful for unwinding. Enjoying a game can definitely give your mind a break from stress. Are there any other activities you're finding helpful or enjoyable right now?

        You: Which can
        HeyFriend: It seems like gaming is offering you some positive distraction, which can be really beneficial. Having activities that help shift focus away from stress is important. Are there any other hobbies or interests you're exploring or considering right now?

        You: Be
        You: Be really
        HeyFriend: It sounds like you're in the middle of a thought. Would you like to continue, or is there anything else you'd like to share or discuss?
        HeyFriend: It looks like your message got cut off. Could you please resend what you were saying?

        You: Yes so I would like to continue just saying that like overall I've had a really good experience with my travels and coming back into things and yeah
        HeyFriend: I'm glad to hear that your travels were a positive experience and that you're feeling good about getting back into the swing of things. It sounds like you're in a good place to move forward with whatever comes next. Is there anything specific you're looking forward to or focusing on as you settle back in?

        You: Yeah I'm looking forward to honestly applying to jobs again even though I'm exhausted about it but I'm also just looking forward to just being back into
        HeyFriend: It's great that you're feeling ready to dive back into job applications, even if it feels a bit exhausting. It sounds like you're eager to regain your routine and sense of normalcy. Is there anything specific you're planning to do differently this time around, or anything you're particularly excited about in the process?

        You: I think I'm excited just about I guess being in that rhythm like there's something about getting stuff done and at the end of the day knowing you got stuff done that it's really really nice to feel that and I don't know I looked back on it and I'm grateful for that right like I'm grateful for the fact I'm thankful for the fact that I had a productive day
        HeyFriend: That's a wonderful perspective. The sense of accomplishment from a productive day can be really fulfilling and motivating. It's great that you appreciate and value that feeling. It can make the process of job hunting and getting back into a routine more rewarding. Do you have any specific goals or steps in mind to help maintain that productive rhythm?

        You: Yeah like maintaining my schedule I wake up I go to the gym I do honestly have kind of like a little place to write down all my task for the day but that's kind of what I do
        HeyFriend: That sounds like a solid plan! Having a routine with activities like going to the gym and writing down tasks can really help maintain productivity and focus. It’s great that you have a system in place that works for you. How are you finding it so far? Is there anything you'd like to tweak or add to your routine?

        You: I'm actually finding it extremely helpful not helpful honestly I only write like a max of like 5 to 6 things a day that I need to
        You: I'm actually finding it extremely helpful not helpful
        HeyFriend: It sounds like you're finding your routine helpful overall, despite the challenges. Keeping your task list to a manageable number like 5 or 6 things can prevent overwhelm and help you focus on what's most important. Do you feel that approach is working well for you, or is there anything you'd like to adjust?
        HeyFriend: It sounds like keeping your task list manageable is really working for you. Focusing on a few key tasks each day can help avoid overwhelm and make it easier to stay on track. It’s great that you’ve found a balance that feels helpful. Is there anything specific you find particularly effective in sticking to your routine?

        You: I think my partner helps me a ton I think just her being there not verbally saying something but just being there physically actually helps me a ton because I don't know what it is just having another body around you forces you to actually make yourself accountable and keep yourself accountable if that makes sense
        HeyFriend: That makes perfect sense. Having a supportive partner present can be incredibly grounding and motivating. It's great that her presence helps you stay accountable and focused. It sounds like you have a strong support system. How is she finding things lately?

        You: I mean she's proud of me which is really cool … I recently just got hired on contract to make a website … and honestly she was extremely proud of me …
        You: … I produced it and honestly she was extremely proud of me … the feeling that I get out of productivity
        HeyFriend: Congratulations on the contract! …
        HeyFriend: That's fantastic news! …

        You: Honestly I felt really good … I built the website … business cards … new logo … Google presence … debating whether I should just do this in the meantime while I'm unemployed …
        HeyFriend: That's an impressive accomplishment … Have you considered … more freelance opportunities?

        You: I haven't but it has been a thought …
        HeyFriend: It's great that you're considering it …

        You: Why not both
        HeyFriend: That sounds like a balanced approach! …

        You: Honestly I find a balance of just setting a schedule and … time boxing …
        HeyFriend: Time boxing sounds like an effective strategy …

        You: Honestly I feel great … getting my life back together …
        HeyFriend: That's wonderful to hear! …

        You: I think just make sure making sure that I keep myself accountable … go with the flow right now …
        You: I think … honesty … checking in with myself …
        HeyFriend: Going with the flow can be a healthy … Is there anything specific you're using to help keep yourself accountable?
        HeyFriend: That’s a great mindset …

        You: Again just having a partner … let's move onto another topic …
        HeyFriend: Of course! …

        You: How about you choose
        HeyFriend: Sure! How about we talk about travel? …

        You: … Europe … Portugal …
        HeyFriend: Portugal sounds like a fantastic choice! …

        You: What do you know about Madeira Portugal
        HeyFriend: Madeira is a beautiful archipelago …

        You: … looks like Hawaii
        HeyFriend: Madeira does have that lush, tropical vibe …

        You: Kinda mix of both …
        HeyFriend: That sounds like a perfect plan! …

        You: … fruits … authentic
        HeyFriend: I understand what you mean … fresh, locally grown fruits …

        You: I actually am a fan
        HeyFriend: That's wonderful! … cuisine …

        You: Probably some lobster
        HeyFriend: Lobster sounds like a delicious choice! …

        You: I'm getting bored … let's talk about something else
        HeyFriend: Sure, let's switch it up! …
        HeyFriend: No problem! …

        You: … you choose … really really interesting …
        HeyFriend: Sure thing! … space exploration …

        You: … confused … if we already landed on the moon why haven’t we been back sooner
        You: (repeat with corrected wording)
        HeyFriend: That's a great question! … Artemis …

        HeyFriend: (another explanation)
        You: It's cool but is it really that much more helpful …
        HeyFriend: Understandable … unique opportunities …

        You: What's something that you find super interesting
        HeyFriend: Exoplanets …

        You: I'm more intrigued by AI … worried it might take over …
        HeyFriend: AI … benefits vs risks …

        You: … only seen the benefits … productivity … game changer …
        HeyFriend: Great to hear … stay mindful …

        You: … AI has helped me a ton in building an app
        You: I'm thinking honestly
        HeyFriend: Sounds like AI has been a valuable tool … features …
        HeyFriend: That's fantastic! …

        You: Well I started building a conversational AI app
        HeyFriend: That sounds exciting! …

        You: … text to speech, speech recognition … analysis of speech and transcript
        HeyFriend: Those are great features …
        """

//        // ====== Stub the 3 OpenAI calls your pipeline makes ======
//        // 1) summarizeChunk
//        MockURLProtocol.enqueue(json:
//        #"{ "choices":[{ "message":{ "content":"{\"bullets\":[\"loan stress\",\"group approach\",\"planning a talk\"],\"gratitude_mentions\":0,\"local_tone\":\"Calm\",\"language\":{\"repeated_words\":[\"money\"],\"thinking_style\":\"practical\",\"emotional_indicators\":\"calm\"}}" } }] }"#
//        )
//
//        // 2) finalizeSummary
//        MockURLProtocol.enqueue(json:
//        #"{ "choices":[{ "message":{ "content":"{\"bullets\":[\"loan stress\",\"planning a talk\"]}" } }] }"#
//        )
//
//        // 3) final generateSummary call (model UNDERCOUNTS gratitude = 1)
//        MockURLProtocol.enqueue(json:
//        #"{ "choices":[{ "message":{ "content":"{\"summary\":[\"Unpaid loan causing tension\",\"Considering a conversation\",\"Wants clear next steps\"],\"tone\":\"Frustrated\",\"supporting_tones\":[\"Hopeful\"],\"tone_note\":\"User is upset but future-oriented\",\"language\":{\"repeated_words\":[\"money\"],\"thinking_style\":\"practical\",\"emotional_indicators\":\"frustrated but hopeful\"},\"recommendation\":\"Try scheduling a calm, time-boxed conversation with a repayment plan.\",\"gratitude_mentions\":1}" } }] }"#
//        )
        
        // ====== Stub the 3 OpenAI calls your pipeline makes ======
        // 1) summarizeChunk (entire convo likely fits one chunk; either way this gets used)
        MockURLProtocol.enqueue(json:
        #"{ "choices":[{ "message":{ "content":"{\"bullets\":[\"Travel back; re-starting job hunt\",\"Sleep + routine restore mood\",\"Considering freelancing while applying\"],\"gratitude_mentions\":2,\"local_tone\":\"Hopeful\",\"language\":{\"repeated_words\":[\"honestly\",\"really\",\"grateful\",\"sleep\"],\"thinking_style\":\"future-focused, practical\",\"emotional_indicators\":\"renewed motivation\"}}" } }] }"#
        )

        // 2) finalizeSummary (merge bullets to ≤6)
        MockURLProtocol.enqueue(json:
        #"{ "choices":[{ "message":{ "content":"{\"bullets\":[\"Returning to routine after travel\",\"Job hunt with time-boxing\",\"Partner support boosts accountability\",\"Considering freelance web work\"]}" } }] }"#
        )

        // 3) final generateSummary (UNDERCOUNT gratitude to 1 to exercise the guard)
        MockURLProtocol.enqueue(json:
        #"{ "choices":[{ "message":{ "content":"{\"summary\":[\"Back from travel; rebuilding routine\",\"Balancing job search and possible freelancing\",\"Sleep, gym, and schedules help mood\"],\"tone\":\"Hopeful\",\"supporting_tones\":[\"Motivated\"],\"tone_note\":\"User feels productive and forward-looking despite anxiety about job hunt.\",\"language\":{\"repeated_words\":[\"sleep\",\"schedule\",\"productive\"],\"thinking_style\":\"future-focused\",\"emotional_indicators\":\"optimistic and grounded\"},\"recommendation\":\"Keep time-boxing: 2h job search, 1–2h portfolio/app work, 2h client work; preserve sleep window.\",\"gratitude_mentions\":1}" } }] }"#
        )

        let exp = expectation(description: "summary")
        XCTAssertEqual(MockURLProtocol.responseQueue.count, 3)
        
//        XCTAssertEqual(MockURLProtocol.responseQueue.count, 3, "Expect 3 mocked responses for 3 requests")
        
        
        ChatService.shared.generateSummary(sessionId: "REAL-\(UUID().uuidString)", transcript: transcript) { mapped in
            XCTAssertNotNil(mapped)
//        ChatService.shared.generateSummary(sessionId: "TEST-\(UUID().uuidString)", transcript: transcript) { mapped in
//            XCTAssertNotNil(mapped, "Mapped summary should not be nil")
            guard let s = mapped else { exp.fulfill(); return }
            
            // Summary bullets are user-centric (not “assistant suggests” phrasing)
//            XCTAssertFalse(s.summary.contains(where: { $0.lowercased().contains("assistant") }))
            
            // High-level sanity
            XCTAssertFalse(s.summary.isEmpty)
            XCTAssertEqual(s.tone, "Hopeful")
            
            // Gratitude guard: model says 1, transcript has 4
            XCTAssertEqual(s.gratitudeMentions, 4)

            // No hidden calls
            XCTAssertTrue(MockURLProtocol.responseQueue.isEmpty)


//            // Language object present and grounded
//            if let lang = s.language {
//                // No filler like "really" or "think"
//                let fillers = Set(["really","think","just","kinda","kind","sort","sort of","you know"])
//                XCTAssertTrue(lang.repeatedWords.allSatisfy { !fillers.contains($0.lowercased()) })
//            }
//
//            // We consumed all network stubs (no hidden calls)
//            XCTAssertTrue(MockURLProtocol.responseQueue.isEmpty)
//            // Bullets come back
//            XCTAssertFalse(s.summary.isEmpty, "Bullets should exist")
//            // Tone passes through
//            XCTAssertEqual(s.tone, "Frustrated")
//            // Heuristic must beat the model’s 1 (we had 2 gratitude utterances in transcript)
//            XCTAssertEqual(s.gratitudeMentions, 2, "Heuristic should raise gratitude to 2")
//
//            // Ensure the final user message content includes our full-session source
//            if let body = MockURLProtocol.lastRequestBodyJSON,
//               let messages = body["messages"] as? [[String: Any]],
//               let userMsg = messages.last,
//               let content = userMsg["content"] as? String {
//                XCTAssertTrue(content.contains("Representative USER snippets"))
//                XCTAssertTrue(content.lowercased().contains("grateful for my wife"))
//                XCTAssertTrue(content.lowercased().contains("grateful for the sunny weather"))
//            }
//
//            // optional: confirm all stubs consumed
//            XCTAssertTrue(MockURLProtocol.responseQueue.isEmpty)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }
}
