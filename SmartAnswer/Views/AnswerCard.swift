import SwiftUI

struct AnswerCard: View {
    let question: Question
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(question.source == "local" ? "📚 题库命中" : "🤖 \(question.source)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            
            Text(question.answer)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if !question.question.isEmpty {
                Text(question.question)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: question.source == "local" 
                    ? [Color.green, Color.blue] 
                    : [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}
