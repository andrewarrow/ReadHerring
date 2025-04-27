import SwiftUI
import Foundation
import AVFoundation

struct ReadAlongView: View {
    @State private var currentPageIndex = 0
    @State private var screenplay: ScreenplaySummary
    @Environment(\.presentationMode) var presentationMode
    
    // Hard-coded fade.txt content split into pages
    private var pages: [String] = []
    
    init() {
        // Load the default screenplay text from fade.txt
        let defaultScreenplayText = """
                              STARTUP MELTDOWN

                           Written by Assistant



FADE IN:

INT. TECH STARTUP OFFICE - MORNING

The office is buzzing with nervous energy. Banners reading
"LAUNCH DAY!" hang everywhere. SARAH (30s, CEO, stressed but
trying to appear calm) paces while checking her phone.

                         SARAH
          Has anyone seen the demo unit?
          Anyone?

MIKE (20s, software engineer, disheveled) rushes in, coffee
stains on his shirt.

                         MIKE
          I swear I put it in the conference
          room last night!

JESSICA (30s, marketing director, perpetually optimistic)
bounds in carrying a box of promotional swag.

                         JESSICA
          Don't worry! I have backup units.
          Well, they're prototypes from six
          months ago, but they're basically
          the same thing, right?

                         SARAH
                    (horrified)
          The ones that catch fire?

DAVID (40s, CFO, always with a calculator) enters, looking
pale.

                         DAVID
          Speaking of fire, our insurance
          company just called. Apparently,
          they're concerned about our
          "history of combustible
          presentations."

EMILY (20s, PR manager, fashion-forward) struts in while on
the phone.

                         EMILY
                    (into phone)
          No, TechCrunch, we're NOT the
          company that accidentally sent
          10,000 units to a goat farm...
          Okay, maybe we are.

RYAN (30s, head of sales, overly confident) enters with a
swagger.

                         RYAN
          Ladies and gentlemen, don't panic.
          I've got this totally under
          control. I've invited every major
          tech journalist, blogger, and
          influencer within a 100-mile
          radius.

                         SARAH
          That's what I'm afraid of.


INT. CONFERENCE ROOM - ONE HOUR LATER

The team frantically sets up for the presentation. JESSICA
struggles with tangled cables while MIKE types furiously on
his laptop.

                         MIKE
          The presentation software just
          crashed. Again.

                         EMILY
          Use PowerPoint?

                         MIKE
                    (horrified)
          We're a tech company! We can't use
          PowerPoint! What will people think?

                         DAVID
          They'll think we're competent?

SARAH checks her watch nervously.

                         SARAH
          We have fifteen minutes. Where's
          the keynote speaker?

                         RYAN
          About that... Remember how I said I
          booked Elon Musk?

                         SARAH
          Yes?

                         RYAN
          Well, I actually booked Elon
          Musk... the children's party
          entertainer.

Everyone stares at RYAN in disbelief.

                         JESSICA
                 (trying to be positive)
          Maybe he can juggle our products?


INT. CONFERENCE ROOM - LAUNCH EVENT

The room is packed with journalists and influencers. The team
stands nervously on stage. PARTY ENTERTAINER ELON (50s,
dressed like a budget magician) juggles three prototype
devices.

                      PARTY ELON
          And now, watch as I make your
          expectations... disappear!

One of the devices slips and crashes to the floor, breaking
into pieces. The audience gasps.

                         SARAH
                  (whispering to MIKE)
          Please tell me that wasn't the only
          working unit.

                         MIKE
                  (whispering back)
          Define "working."

EMILY steps forward, attempting damage control.

                         EMILY
          What you just witnessed was our
          revolutionary self-disassembling
          feature!

The journalists start murmuring and taking notes.

                         JESSICA
                    (improvising)
          Yes! For the environmentally
          conscious consumer who wants their
          tech to return to its natural
          state!

DAVID pulls out his calculator, frantically punching numbers.

                         DAVID
          We're either going bankrupt or
          becoming billionaires. I can't tell
          which.


INT. CONFERENCE ROOM - LATER

The Q&A session has begun. A TECH JOURNALIST raises his hand.

                     TECH JOURNALIST
          Your press release mentions AI
          integration. Can you demonstrate?

SARAH looks at MIKE, who looks terrified.

                         MIKE
                    (whispering)
          The AI thinks it's a toaster.

                         SARAH
                    (to audience)
          Our AI is so advanced, it's...
          taking a personal day.

RYAN jumps in, trying to save the situation.

                         RYAN
          But wait! We have something even
          better! Jessica, bring out the
          special surprise!

JESSICA wheels in a cart covered by a sheet.

                         JESSICA
          Behold, our latest innovation!

She pulls off the sheet, revealing a regular toaster with
their company logo stuck on it.

                         EMILY
                    (improvising)
          It's our new smart toaster! It...
          uh... syncs with your calendar to
          predict when you'll want toast!

The audience looks confused but intrigued.


INT. BACKSTAGE AREA - CONTINUOUS

The team huddles while PARTY ELON continues entertaining the
crowd with balloon animals.

                         SARAH
          This is a disaster. We're finished.

                         DAVID
          Actually, our pre-orders just went
          up 300%.

                        EVERYONE
          What?!

                         DAVID
          Apparently, people love the idea of
          a self-destructing phone. They're
          calling it "planned obsolescence
          taken to its logical conclusion."

                         MIKE
          And the toaster thing is trending
          on Twitter.

                         JESSICA
          I told you optimism works!


INT. CONFERENCE ROOM - END OF EVENT

The team takes their final bow. The audience is actually
applauding.

                         SARAH
                    (to the audience)
          Thank you all for coming to witness
          the future of technology.
          Remember, sometimes the best
          innovations come from happy
          accidents!

A device in the background catches fire. EMILY quickly throws
a promotional t-shirt over it.

                         EMILY
          And that concludes our
          demonstration of rapid heating
          technology!

The audience cheers. The team exchanges bewildered looks.


INT. OFFICE - NEXT DAY

The team sits around a table, reading headlines on their
devices.

                         RYAN
          "Revolutionary Tech Company
          Embraces Chaos." We're famous!

                         JESSICA
          The toaster pre-orders alone will
          keep us afloat for a year.

                         SARAH
          I can't believe this worked.

                         MIKE
          Should we tell them the AI really
          does think it's a toaster?

                         DAVID
                (looking at numbers)
          At these profit margins? Let it
          think it's a waffle iron for all I
          care.

PARTY ELON enters, still in costume.

                      PARTY ELON
          Hey, do you guys need a Chief Magic
          Officer?

Everyone laughs.

                         SARAH
          You know what? Why not. Welcome to
          the team.

                         EMILY
          I'll draft the press release: "Tech
          Startup Hires Actual Wizard."

                         JESSICA
          This is either the best or worst
          decision we've ever made.

                         SARAH
          In this company, those are usually
          the same thing.

They all raise their coffee mugs in a toast.

                          ALL
          To happy accidents!

FADE OUT.


                         THE END
"""
        
        // Parse the screenplay using the existing parser
        self._screenplay = State(initialValue: ScreenplayParser.parseScreenplay(text: defaultScreenplayText))
        
        // Split the text into pages (around 30 lines per page)
        let lines = defaultScreenplayText.components(separatedBy: .newlines)
        let linesPerPage = 30
        var currentPage = ""
        var pageIndex = 0
        
        for (index, line) in lines.enumerated() {
            currentPage += line + "\n"
            
            if (index + 1) % linesPerPage == 0 || index == lines.count - 1 {
                self.pages.append(currentPage)
                currentPage = ""
                pageIndex += 1
            }
        }
        
        // If there's any content left, add it as the last page
        if !currentPage.isEmpty {
            self.pages.append(currentPage)
        }
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("ReadAlong")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Page indicator
                Text("\(currentPageIndex + 1)/\(pages.count)")
                    .padding(.horizontal)
            }
            .padding(.top, 30)
            
            // Screenplay content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pages[currentPageIndex])
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Swipe up to go to next page
                        if value.translation.height < -50 && currentPageIndex < pages.count - 1 {
                            withAnimation {
                                currentPageIndex += 1
                            }
                        }
                        // Swipe down to go to previous page
                        else if value.translation.height > 50 && currentPageIndex > 0 {
                            withAnimation {
                                currentPageIndex -= 1
                            }
                        }
                    }
            )
            
            // Navigation buttons
            HStack {
                Button(action: {
                    if currentPageIndex > 0 {
                        withAnimation {
                            currentPageIndex -= 1
                        }
                    }
                }) {
                    Image(systemName: "arrow.up")
                        .padding()
                        .background(currentPageIndex > 0 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(currentPageIndex == 0)
                
                Spacer()
                
                Button(action: {
                    if currentPageIndex < pages.count - 1 {
                        withAnimation {
                            currentPageIndex += 1
                        }
                    }
                }) {
                    Image(systemName: "arrow.down")
                        .padding()
                        .background(currentPageIndex < pages.count - 1 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(currentPageIndex == pages.count - 1)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

struct ReadAlongView_Previews: PreviewProvider {
    static var previews: some View {
        ReadAlongView()
    }
}